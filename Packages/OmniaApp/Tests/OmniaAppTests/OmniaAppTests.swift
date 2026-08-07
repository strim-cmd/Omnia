import Foundation
import OmniaApplication
import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaApp

// MARK: - Shared test doubles

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

/// A provider adapter double that records the endpoint and credential reference
/// it is constructed with and returns canned responses, so the runtime binding
/// is tested without a network (ARC-001, ARC-006).
private final class FakeProviderAdapter: TextGenerationContract, ConversationContract, StreamingContract, @unchecked Sendable {
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        TextGenerationResponse(text: "generated reply")
    }

    func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        ConversationResponse(message: Message(role: .assistant, content: "assistant reply"))
    }

    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                .completion(
                    identity: request.identity,
                    message: Message(role: .assistant, content: "streamed reply")
                )
            )
            continuation.finish()
        }
    }
}

/// Records the endpoints and credentials the binding's adapter factory is asked
/// to construct adapters for.
private final class RecordingAdapterFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCalls: [(endpoint: URL, credential: CredentialReference)] = []
    private let adapter = FakeProviderAdapter()

    func make(
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> any TextGenerationContract & ConversationContract & StreamingContract {
        lock.withLock {
            recordedCalls.append((endpoint, credential))
        }
        return adapter
    }

    var calls: [(endpoint: URL, credential: CredentialReference)] {
        lock.withLock { recordedCalls }
    }
}

// MARK: - Helpers

private let modelReference = ModelReference(name: AppEdgeConstants.defaultModelName)

private func connection(
    identity: ProviderIdentity = ProviderIdentity()
) -> ProviderConnection {
    ProviderConnection(
        identity: identity,
        capabilities: ProviderCapabilities(
            capabilities: [.textGeneration, .conversation, .streaming]
        ),
        metadata: ProviderMetadata(displayName: "Test Provider"),
        limits: ProviderLimits(),
        version: SemanticVersion(major: 1, minor: 0, patch: 0)
    )
}

private func makeConfigureRequest() -> ConfigureProviderRequest {
    ConfigureProviderRequest(
        displayName: "Test Provider",
        capabilities: ProviderCapabilities(
            capabilities: [.textGeneration, .conversation, .streaming]
        ),
        limits: ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion(major: 1, minor: 0, patch: 0),
        credential: Credential(secret: "sk-test-secret-that-must-never-leak")
    )
}

// MARK: - CompositionRoot

final class CompositionRootTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        super.tearDown()
    }

    private func makeTemporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniaAppTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(url)
        return url
    }

    private func makeComposition() throws -> CompositionRoot {
        CompositionRoot(storageRoot: try makeTemporaryRoot())
    }

    func testCompositionRootAssemblesTheGraph() throws {
        let root = try makeTemporaryRoot()
        let composition = CompositionRoot(storageRoot: root)
        XCTAssertEqual(composition.storageRoot, root)
        // Every service and surface is composed with every collaborator
        // injected; accessing each forces the assembled graph to exist.
        _ = composition.workspaceService
        _ = composition.conversationService
        _ = composition.providerConnectionService
        _ = composition.configurationService
        _ = composition.sendMessageUseCase
        _ = composition.selectionService
        _ = composition.lifecycleService
        _ = composition.navigationSurface.conversationList
        _ = composition.navigationSurface.conversationScreen
        _ = composition.navigationSurface.settings
    }

    func testComposedConfigurationServiceRoundTripsThroughTheStorageLayout() async throws {
        let composition = try makeComposition()
        let key = ConfigurationKey<String>("test.key")
        try await composition.configurationService.store("value", for: key, at: .globalDefault)
        let value = try await composition.configurationService.value(for: key, at: .globalDefault)
        XCTAssertEqual(value, "value")
    }

    func testPrepareCreatesDefaultWorkspaceOnFirstLaunch() async throws {
        let composition = try makeComposition()
        let identity = try await composition.prepare()
        let workspace = try await composition.workspaceService.workspace(with: identity)
        XCTAssertNotNil(workspace)
        XCTAssertEqual(workspace?.name, AppEdgeConstants.defaultWorkspaceName)
        let recorded = try await composition.configurationService.value(
            for: AppEdgeConstants.defaultWorkspaceIdentityKey,
            at: .globalDefault
        )
        XCTAssertEqual(recorded, identity.canonicalString)
    }

    func testPrepareIsIdempotentAcrossLaunches() async throws {
        let composition = try makeComposition()
        let first = try await composition.prepare()
        let second = try await composition.prepare()
        XCTAssertEqual(second, first)
        let workspace = try await composition.workspaceService.workspace(with: first)
        XCTAssertNotNil(workspace)
    }

    func testPrepareRerecordsDefaultWorkspaceWhenTheRecordedOneIsMissing() async throws {
        let composition = try makeComposition()
        let first = try await composition.prepare()
        try FileManager.default.removeItem(
            at: composition.storageRoot.appendingPathComponent("Workspaces", isDirectory: true)
        )
        let second = try await composition.prepare()
        XCTAssertNotEqual(second, first)
        let workspace = try await composition.workspaceService.workspace(with: second)
        XCTAssertNotNil(workspace)
        let recorded = try await composition.configurationService.value(
            for: AppEdgeConstants.defaultWorkspaceIdentityKey,
            at: .globalDefault
        )
        XCTAssertEqual(recorded, second.canonicalString)
    }

    func testPrepareWithoutProvidersStillBootstrapsWorkspace() async throws {
        let composition = try makeComposition()
        let identity = try await composition.prepare()
        let workspace = try await composition.workspaceService.workspace(with: identity)
        XCTAssertNotNil(workspace)
        let selection = await composition.selectionService.select(requiredCapability: .streaming)
        XCTAssertEqual(selection, .failure)
    }

    func testPrepareRegistersStoredProvidersAsReady() async throws {
        let composition = try makeComposition()
        let connection = try await composition.providerConnectionService.configure(
            makeConfigureRequest()
        )
        _ = try await composition.prepare()
        let state = await composition.lifecycleService.state(of: connection.identity)
        XCTAssertEqual(state, .ready)
        let selection = await composition.selectionService.select(requiredCapability: .streaming)
        guard case .selected(provider: let provider, model: let model) = selection else {
            return XCTFail("Expected a selected provider")
        }
        XCTAssertEqual(provider, connection.identity)
        XCTAssertEqual(model, modelReference)
    }

    func testRepeatedPrepareKeepsProvidersReady() async throws {
        let composition = try makeComposition()
        let connection = try await composition.providerConnectionService.configure(
            makeConfigureRequest()
        )
        _ = try await composition.prepare()
        _ = try await composition.prepare()
        let state = await composition.lifecycleService.state(of: connection.identity)
        XCTAssertEqual(state, .ready)
    }

    func testStorageLayoutCreatesDirectoriesLazilyOnSave() async throws {
        let root = try makeTemporaryRoot()
        let composition = CompositionRoot(storageRoot: root)
        let workspaces = root.appendingPathComponent("Workspaces", isDirectory: true)
        let configuration = root.appendingPathComponent("Configuration", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspaces.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.path))
        _ = try await composition.prepare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspaces.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.path))
    }

    func testPlatformStorageRootIsInsideApplicationSupport() {
        let root = StorageLayout.platformRoot()
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        XCTAssertTrue(root.path.hasPrefix(base.path))
        XCTAssertEqual(root.lastPathComponent, AppEdgeConstants.storageRootDirectoryName)
    }
}

// MARK: - ProviderAdapterBinding

final class ProviderAdapterBindingTests: XCTestCase {
    private func makeConfigurationService() -> ConfigurationService {
        ConfigurationService(
            configurationRepository: InMemoryConfigurationRepository(),
            resolutionPolicy: ConfigurationResolutionPolicy()
        )
    }

    private func register(
        _ lifecycle: ProviderLifecycleService,
        identity: ProviderIdentity,
        ready: Bool = true
    ) async throws {
        let registered = await lifecycle.register(connection(identity: identity))
        guard ready else { return }
        try await lifecycle.transition(registered, to: .validated)
        try await lifecycle.transition(registered, to: .initializing)
        try await lifecycle.transition(registered, to: .ready)
    }

    private func makeBinding(
        providerIdentity: ProviderIdentity = ProviderIdentity(),
        isReady: Bool = true,
        endpoint: String? = "https://api.example.com/v1",
        credentialReference: CredentialReference? = CredentialReference()
    ) async throws -> (binding: ProviderAdapterBinding, factory: RecordingAdapterFactory, identity: ProviderIdentity) {
        let lifecycle = ProviderLifecycleService()
        try await register(lifecycle, identity: providerIdentity, ready: isReady)
        let configurationService = makeConfigurationService()
        if let endpoint {
            try await configurationService.store(
                endpoint,
                for: ProviderConnectionService.endpointKey(for: providerIdentity),
                at: .providerSettings
            )
        }
        if let credentialReference {
            try await configurationService.store(
                credentialReference,
                for: ProviderConnectionService.credentialReferenceKey(for: providerIdentity),
                at: .providerSettings
            )
        }
        let factory = RecordingAdapterFactory()
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: { _ in [modelReference] },
            adapterFactory: { resolvedEndpoint, resolvedReference in
                try await factory.make(endpoint: resolvedEndpoint, credential: resolvedReference)
            }
        )
        return (binding, factory, providerIdentity)
    }

    private func makeEmptyBinding() -> ProviderAdapterBinding {
        ProviderAdapterBinding(
            lifecycleService: ProviderLifecycleService(),
            configurationService: makeConfigurationService(),
            preferredModels: { _ in [modelReference] },
            adapterFactory: { _, _ in throw CapabilityError.providerUnavailable }
        )
    }

    func testGenerateTextResolvesTheProviderOfferingTheModel() async throws {
        let endpoint = "https://api.example.com/v1"
        let reference = CredentialReference()
        let (binding, factory, _) = try await makeBinding(
            endpoint: endpoint,
            credentialReference: reference
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        let response = try await binding.generateText(from: request)
        XCTAssertEqual(response.text, "generated reply")
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.calls[0].endpoint, URL(string: endpoint))
        XCTAssertEqual(factory.calls[0].credential, reference)
    }

    func testSendMessageResolvesTheProviderOfferingTheModel() async throws {
        let (binding, factory, _) = try await makeBinding()
        let request = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference
        )
        let response = try await binding.sendMessage(request)
        XCTAssertEqual(response.message, Message(role: .assistant, content: "assistant reply"))
        XCTAssertEqual(factory.calls.count, 1)
    }

    func testStreamResolvesTheProviderOfferingTheModel() async throws {
        let (binding, factory, _) = try await makeBinding()
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference
        )
        let stream = try await binding.stream(request)
        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }
        XCTAssertEqual(
            updates,
            [.completion(identity: request.identity, message: Message(role: .assistant, content: "streamed reply"))]
        )
        XCTAssertEqual(factory.calls.count, 1)
    }

    func testThrowsProviderUnavailableWhenNoProviderExists() async throws {
        let binding = makeEmptyBinding()
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
    }

    func testThrowsProviderUnavailableWhenProviderIsNotReady() async throws {
        let (binding, _, _) = try await makeBinding(isReady: false)
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
    }

    func testThrowsProviderUnavailableWhenProviderHasNoRecordedEndpoint() async throws {
        let (binding, _, _) = try await makeBinding(endpoint: nil)
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
    }

    func testThrowsProviderUnavailableWhenProviderHasNoRecordedCredential() async throws {
        let (binding, _, _) = try await makeBinding(credentialReference: nil)
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
    }

    func testResolvesTheCanonicalFirstProviderWhenSeveralOfferTheModel() async throws {
        let first = ProviderIdentity()
        let second = ProviderIdentity()
        let ordered = [first, second].sorted { $0.canonicalString < $1.canonicalString }
        let smaller = ordered[0]
        let larger = ordered[1]

        let lifecycle = ProviderLifecycleService()
        try await register(lifecycle, identity: smaller)
        try await register(lifecycle, identity: larger)
        let configurationService = makeConfigurationService()
        try await configurationService.store(
            "https://smaller.example.com/v1",
            for: ProviderConnectionService.endpointKey(for: smaller),
            at: .providerSettings
        )
        try await configurationService.store(
            "https://larger.example.com/v1",
            for: ProviderConnectionService.endpointKey(for: larger),
            at: .providerSettings
        )
        try await configurationService.store(
            CredentialReference(),
            for: ProviderConnectionService.credentialReferenceKey(for: smaller),
            at: .providerSettings
        )
        try await configurationService.store(
            CredentialReference(),
            for: ProviderConnectionService.credentialReferenceKey(for: larger),
            at: .providerSettings
        )
        let factory = RecordingAdapterFactory()
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: { _ in [modelReference] },
            adapterFactory: { resolvedEndpoint, resolvedReference in
                try await factory.make(endpoint: resolvedEndpoint, credential: resolvedReference)
            }
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        _ = try await binding.generateText(from: request)
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.calls[0].endpoint, URL(string: "https://smaller.example.com/v1"))
    }

    private func assertThrowsProviderUnavailable(
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected CapabilityError.providerUnavailable")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .providerUnavailable)
        } catch {
            XCTFail("Expected CapabilityError.providerUnavailable, got \(error)")
        }
    }
}

// MARK: - AppLaunch

final class AppLaunchTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        super.tearDown()
    }

    private func makeTemporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniaAppTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(url)
        return url
    }

    func testLaunch_ComposesTheGraphAndResolvesTheDefaultWorkspace() async throws {
        let launch = try await AppLaunch(storageRoot: try makeTemporaryRoot())
        XCTAssertFalse(launch.workspace.canonicalString.isEmpty)
        // The composed graph is complete: every surface the shell hosts is
        // delivered through the navigation surface (DES-012 §3.6).
        _ = launch.composition.navigationSurface.conversationList
        _ = launch.composition.navigationSurface.conversationScreen
        _ = launch.composition.navigationSurface.settings
    }

    func testLaunch_ResolvesThePersistedDefaultWorkspace() async throws {
        let launch = try await AppLaunch(storageRoot: try makeTemporaryRoot())
        let workspace = try await launch.composition.workspaceService.workspace(with: launch.workspace)
        XCTAssertNotNil(workspace)
        XCTAssertEqual(workspace?.name, AppEdgeConstants.defaultWorkspaceName)
        let recorded = try await launch.composition.configurationService.value(
            for: AppEdgeConstants.defaultWorkspaceIdentityKey,
            at: .globalDefault
        )
        XCTAssertEqual(recorded, launch.workspace.canonicalString)
    }

    func testLaunch_IsIdempotentAcrossLaunches() async throws {
        let root = try makeTemporaryRoot()
        let first = try await AppLaunch(storageRoot: root)
        let second = try await AppLaunch(storageRoot: root)
        XCTAssertEqual(second.workspace, first.workspace)
        let workspace = try await second.composition.workspaceService.workspace(with: second.workspace)
        XCTAssertNotNil(workspace)
    }

    func testLaunch_ReregistersStoredProvidersAsReady() async throws {
        let root = try makeTemporaryRoot()
        let first = try await AppLaunch(storageRoot: root)
        _ = try await first.composition.providerConnectionService.configure(makeConfigureRequest())
        let second = try await AppLaunch(storageRoot: root)
        let selection = await second.composition.selectionService.select(requiredCapability: .streaming)
        guard case .selected(provider: _, model: let model) = selection else {
            return XCTFail("Expected a selected provider after relaunch")
        }
        XCTAssertEqual(model, modelReference)
    }
}
