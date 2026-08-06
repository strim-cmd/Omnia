import Foundation
import OmniaApplication
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

private final class InMemoryConversationRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConversationIdentity: Conversation] = [:]

    func save(_ conversation: Conversation) async throws {
        lock.withLock {
            storage[conversation.identity] = conversation
        }
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        lock.withLock {
            storage[identity]
        }
    }

    func delete(_ identity: ConversationIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class InMemoryWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [WorkspaceIdentity: Workspace] = [:]

    func save(_ workspace: Workspace) async throws {
        lock.withLock {
            storage[workspace.identity] = workspace
        }
    }

    func workspace(with identity: WorkspaceIdentity) async throws -> Workspace? {
        lock.withLock {
            storage[identity]
        }
    }

    func allWorkspaces() async throws -> [Workspace] {
        lock.withLock {
            Array(storage.values)
        }
    }

    func delete(_ identity: WorkspaceIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class ScriptedStreamingContract: StreamingContract, @unchecked Sendable {
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private final class InMemoryProviderRepository: ProviderRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ProviderIdentity: Provider] = [:]

    func save(_ provider: Provider) async throws {
        lock.withLock {
            storage[provider.identity] = provider
        }
    }

    func provider(with identity: ProviderIdentity) async throws -> Provider? {
        lock.withLock {
            storage[identity]
        }
    }

    func allProviders() async throws -> [Provider] {
        lock.withLock {
            Array(storage.values)
        }
    }

    func delete(_ identity: ProviderIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class InMemoryCredentialStorage: CredentialStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CredentialReference: Credential] = [:]

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = credential
        }
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        guard let credential = lock.withLock({ storage[reference] }) else {
            throw CredentialStorageError.credentialNotFound
        }
        return credential
    }

    func removeCredential(for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = nil
        }
    }
}

private final class InMemoryConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConfigurationLevel: [String: Any]] = [:]

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        let slot = Self.slot(for: key, as: Value.self)
        lock.withLock {
            storage[level, default: [:]][slot] = value
        }
    }

    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        let slot = Self.slot(for: key, as: Value.self)
        return lock.withLock {
            storage[level]?[slot] as? Value
        }
    }

    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        let slot = Self.slot(for: key, as: Value.self)
        lock.withLock {
            storage[level]?[slot] = nil
        }
    }

    private static func slot<Value>(for key: ConfigurationKey<Value>, as type: Value.Type) -> String {
        "\(key.name)\u{0}\(ObjectIdentifier(type))"
    }
}

private func makeConversationListSurface() -> ConversationListSurface {
    ConversationListSurface(
        service: ConversationService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
    )
}

private func makeConversationScreenSurface() -> ConversationScreenSurface {
    let lifecycle = ProviderLifecycleService()
    let selection = ProviderSelectionService(
        lifecycleService: lifecycle,
        preferredModels: { _ in
            [ModelReference(name: "model")]
        }
    )
    return ConversationScreenSurface(
        useCase: SendMessageUseCase(
            streamingContract: ScriptedStreamingContract(),
            selectionService: selection,
            conversationRepository: InMemoryConversationRepository()
        )
    )
}

private func makeSettingsSurface() -> SettingsSurface {
    SettingsSurface(
        connectionService: ProviderConnectionService(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        ),
        configurationService: ConfigurationService(
            configurationRepository: InMemoryConfigurationRepository(),
            resolutionPolicy: ConfigurationResolutionPolicy()
        )
    )
}

private func makeNavigationSurface() -> NavigationSurface {
    NavigationSurface(
        conversationList: makeConversationListSurface(),
        conversationScreen: makeConversationScreenSurface(),
        settings: makeSettingsSurface()
    )
}

private func makeConversation(_ content: String) async throws -> Conversation {
    var conversation = Conversation(identity: ConversationIdentity())
    try conversation.append(Message(role: .user, content: content))
    return conversation
}

private func makeProvider(
    identity: ProviderIdentity,
    displayName: String = "Example Provider"
) -> Provider {
    Provider(
        connection: ProviderConnection(
            identity: identity,
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .conversation]),
            metadata: ProviderMetadata(displayName: displayName),
            limits: ProviderLimits(maxRequestsPerMinute: 60),
            version: SemanticVersion(major: 1, minor: 0, patch: 0)
        )
    )
}

final class NavigationSurfaceTests: XCTestCase {

    // MARK: Hosting the conversation list surface

    func testReachingTheConversationListThroughItsSurface_LoadsTheWorkspaceConversations() async throws {
        let conversations = try await [
            makeConversation("Hello world"),
            makeConversation("Second"),
        ]
        let conversationRepository = InMemoryConversationRepository()
        for conversation in conversations {
            try await conversationRepository.save(conversation)
        }
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Default",
            conversationIdentities: Set(conversations.map(\.identity))
        )
        let workspaceRepository = InMemoryWorkspaceRepository()
        try await workspaceRepository.save(workspace)
        let surface = NavigationSurface(
            conversationList: ConversationListSurface(
                service: ConversationService(
                    conversationRepository: conversationRepository,
                    workspaceRepository: workspaceRepository
                )
            ),
            conversationScreen: makeConversationScreenSurface(),
            settings: makeSettingsSurface()
        )

        let state = try await surface.conversationList.load(in: workspace.identity)

        XCTAssertEqual(state.items.count, 2)
        XCTAssertEqual(
            Set(state.items.map(\.identity)),
            Set(conversations.map(\.identity))
        )
        XCTAssertFalse(state.hasError)
    }

    // MARK: Hosting the conversation screen surface

    func testReachingTheConversationScreenThroughItsSurface_LoadsHistory() throws {
        let identity = ConversationIdentity()
        var conversation = Conversation(identity: identity)
        try conversation.append(Message(role: .user, content: "Hello"))
        try conversation.append(Message(role: .assistant, content: "World"))
        let surface = makeNavigationSurface()

        let state = surface.conversationScreen.load(conversation)

        XCTAssertEqual(state.messages.count, 2)
        XCTAssertEqual(state.messages[0].role, .user)
        XCTAssertEqual(state.messages[1].role, .assistant)
        XCTAssertNil(state.streamingCondition)
        XCTAssertFalse(state.hasError)
    }

    // MARK: Hosting the settings surface

    func testReachingTheSettingsThroughItsSurface_LoadsConnections() async throws {
        let providerRepository = InMemoryProviderRepository()
        let identity = ProviderIdentity()
        try await providerRepository.save(makeProvider(identity: identity))
        let surface = NavigationSurface(
            conversationList: makeConversationListSurface(),
            conversationScreen: makeConversationScreenSurface(),
            settings: SettingsSurface(
                connectionService: ProviderConnectionService(
                    providerRepository: providerRepository,
                    credentialStorage: InMemoryCredentialStorage(),
                    configurationRepository: InMemoryConfigurationRepository()
                ),
                configurationService: ConfigurationService(
                    configurationRepository: InMemoryConfigurationRepository(),
                    resolutionPolicy: ConfigurationResolutionPolicy()
                )
            )
        )

        let state = try await surface.settings.load()

        XCTAssertEqual(state.connections.count, 1)
        XCTAssertEqual(state.connections[0].identity, identity)
        XCTAssertEqual(state.connections[0].displayName, "Example Provider")
        XCTAssertFalse(state.hasError)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let providerRepository = InMemoryProviderRepository()
        try await providerRepository.save(makeProvider(identity: ProviderIdentity()))
        let surface = NavigationSurface(
            conversationList: makeConversationListSurface(),
            conversationScreen: makeConversationScreenSurface(),
            settings: SettingsSurface(
                connectionService: ProviderConnectionService(
                    providerRepository: providerRepository,
                    credentialStorage: InMemoryCredentialStorage(),
                    configurationRepository: InMemoryConfigurationRepository()
                ),
                configurationService: ConfigurationService(
                    configurationRepository: InMemoryConfigurationRepository(),
                    resolutionPolicy: ConfigurationResolutionPolicy()
                )
            )
        )

        let returned = await Task.detached {
            surface
        }.value
        let state = try await returned.settings.load()

        XCTAssertEqual(state.connections.count, 1)
        XCTAssertEqual(state.connections[0].displayName, "Example Provider")
        XCTAssertFalse(state.hasError)
    }
}
