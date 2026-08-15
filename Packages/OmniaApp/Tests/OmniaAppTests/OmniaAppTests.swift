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
    private let lock = NSLock()
    private var recordedModels: [String] = []
    private var recordedTextRequests: [TextGenerationRequest] = []
    private var recordedConversationRequests: [ConversationRequest] = []
    private var recordedStreamingRequests: [StreamingRequest] = []

    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        lock.withLock {
            recordedModels.append(request.model.name)
            recordedTextRequests.append(request)
        }
        return TextGenerationResponse(text: "generated reply")
    }

    func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        lock.withLock {
            recordedModels.append(request.model.name)
            recordedConversationRequests.append(request)
        }
        return ConversationResponse(message: Message(role: .assistant, content: "assistant reply"))
    }

    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        lock.withLock {
            recordedModels.append(request.model.name)
            recordedStreamingRequests.append(request)
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(
                .completion(
                    identity: request.identity,
                    message: Message(role: .assistant, content: "streamed reply")
                )
            )
            continuation.finish()
        }
    }

    var models: [String] {
        lock.withLock { recordedModels }
    }

    var textRequests: [TextGenerationRequest] {
        lock.withLock { recordedTextRequests }
    }

    var conversationRequests: [ConversationRequest] {
        lock.withLock { recordedConversationRequests }
    }

    var streamingRequests: [StreamingRequest] {
        lock.withLock { recordedStreamingRequests }
    }
}

/// Records the endpoints, credentials, and API kinds the binding's adapter
/// factory is asked to construct adapters for.
private final class RecordingAdapterFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCalls: [(endpoint: URL, credential: CredentialReference, kind: ProviderAPIKind)] = []
    private let adapter = FakeProviderAdapter()

    func make(
        endpoint: URL,
        credential: CredentialReference,
        kind: ProviderAPIKind
    ) async throws -> any TextGenerationContract & ConversationContract & StreamingContract {
        lock.withLock {
            recordedCalls.append((endpoint, credential, kind))
        }
        return adapter
    }

    var calls: [(endpoint: URL, credential: CredentialReference, kind: ProviderAPIKind)] {
        lock.withLock { recordedCalls }
    }

    var adapterModels: [String] {
        adapter.models
    }

    var capturedAdapter: FakeProviderAdapter {
        adapter
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
            makeConfigureRequest(),
            endpoint: "https://api.example.com/v1",
            model: modelReference.name
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

    func testPreparePersistsTheReadyStateSoThePresentationSeesAnAvailableProvider() async throws {
        let composition = try makeComposition()
        let connection = try await composition.providerConnectionService.configure(
            makeConfigureRequest()
        )
        _ = try await composition.prepare()
        // The settings and conversation surfaces derive a provider's
        // availability from the persisted state the repository returns, so a
        // provider the lifecycle has actually made ready must be persisted
        // ready — otherwise the conversation UI reports it unavailable while
        // it is available (DES-009 §3.1).
        let providers = try await composition.providerConnectionService.allProviders()
        guard let stored = providers.first(where: { $0.identity == connection.identity }) else {
            return XCTFail("Expected the configured provider to be stored")
        }
        XCTAssertEqual(stored.state, .ready)
    }

    func testPrepareKeepsThePersistedReadyStateAcrossLaunches() async throws {
        let root = try makeTemporaryRoot()
        let first = CompositionRoot(storageRoot: root)
        let connection = try await first.providerConnectionService.configure(makeConfigureRequest())
        _ = try await first.prepare()
        let second = CompositionRoot(storageRoot: root)
        _ = try await second.prepare()
        let providers = try await second.providerConnectionService.allProviders()
        guard let stored = providers.first(where: { $0.identity == connection.identity }) else {
            return XCTFail("Expected the configured provider to be stored")
        }
        XCTAssertEqual(stored.state, .ready)
        let state = await second.lifecycleService.state(of: connection.identity)
        XCTAssertEqual(state, .ready)
    }

    func testPrepareSelectsTheRecordedModelWhenTheProviderRecordsOne() async throws {
        let composition = try makeComposition()
        let combo = "omniroute:gpt-4o"
        let connection = try await composition.providerConnectionService.configure(
            makeConfigureRequest(),
            endpoint: "https://api.example.com/v1",
            model: combo
        )
        _ = try await composition.prepare()
        let selection = await composition.selectionService.select(requiredCapability: .streaming)
        guard case .selected(provider: let provider, model: let model) = selection else {
            return XCTFail("Expected a selected provider")
        }
        XCTAssertEqual(provider, connection.identity)
        XCTAssertEqual(model, ModelReference(name: combo))
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

    func testDurableDraft_RestoresAcrossCompositionRelaunchWithoutDuplication() async throws {
        let root = try makeTemporaryRoot()
        let identity = ConversationIdentity()
        let first = CompositionRoot(storageRoot: root)
        try await first.conversationDraftService.save("unfinished", for: identity)

        let second = CompositionRoot(storageRoot: root)
        let restored = try await second.conversationDraftService.draft(for: identity)

        XCTAssertEqual(restored, "unfinished")
        let configurationFiles = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Configuration", isDirectory: true),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        XCTAssertEqual(configurationFiles.count, 1)
    }

    func testClearData_RemovesChatsAttachmentsProvidersCredentialsReferencesAndSettings() async throws {
        let root = try makeTemporaryRoot()
        let composition = CompositionRoot(storageRoot: root)
        let workspace = try await composition.prepare()
        let conversation = try await composition.conversationService.createConversation(
            in: workspace
        )
        try await composition.conversationDraftService.save(
            "private draft",
            for: conversation.identity
        )
        let provider = try await composition.providerConnectionService.configure(
            makeConfigureRequest(),
            endpoint: "https://api.example.com/v1",
            model: modelReference.name
        )
        let setting = ConfigurationKey<Bool>("appearance.darkMode")
        try await composition.configurationService.store(
            false,
            for: setting,
            at: .workspaceOverride
        )
        _ = try await composition.attachmentService.stage(
            [
                AttachmentImportCandidate(
                    data: Data("private attachment".utf8),
                    fileName: "notes.txt"
                ),
            ],
            existing: []
        )
        // Simulate individually malformed records left by an interrupted or
        // pre-v1 write. List recovery skips them, but explicit Clear Data must
        // still remove their owned documents and credential references.
        try Data("{".utf8).write(
            to: root
                .appendingPathComponent("Conversations", isDirectory: true)
                .appendingPathComponent(conversation.identity.canonicalString)
                .appendingPathExtension("json")
        )
        try Data("[]".utf8).write(
            to: root
                .appendingPathComponent("Providers", isDirectory: true)
                .appendingPathComponent(provider.identity.canonicalString)
                .appendingPathExtension("json")
        )

        try await composition.dataManagementService.clearAll()

        let conversations = try await composition.conversationService.conversations(in: workspace)
        let providers = try await composition.providerConnectionService.allProviders()
        let draft = try await composition.conversationDraftService.draft(for: conversation.identity)
        let appearance = try await composition.configurationService.value(
            for: setting,
            at: .workspaceOverride
        )
        let retainedWorkspace = try await composition.workspaceService.workspace(with: workspace)
        let lifecycleState = await composition.lifecycleService.state(of: provider.identity)
        let attachmentDirectory = root.appendingPathComponent("Attachments", isDirectory: true)
        let attachmentFiles = (try? FileManager.default.contentsOfDirectory(
            at: attachmentDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let conversationFiles = (try? FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Conversations", isDirectory: true),
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "json" } ?? []
        let providerFiles = (try? FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Providers", isDirectory: true),
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "json" } ?? []

        XCTAssertTrue(conversations.isEmpty)
        XCTAssertTrue(providers.isEmpty)
        XCTAssertEqual(draft, "")
        XCTAssertNil(appearance)
        XCTAssertNotNil(retainedWorkspace)
        XCTAssertTrue(retainedWorkspace?.conversationIdentities.isEmpty == true)
        XCTAssertTrue(retainedWorkspace?.providerIdentities.isEmpty == true)
        XCTAssertNil(lifecycleState)
        XCTAssertTrue(attachmentFiles.isEmpty)
        XCTAssertTrue(conversationFiles.isEmpty)
        XCTAssertTrue(providerFiles.isEmpty)
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
        credentialReference: CredentialReference? = CredentialReference(),
        model: String? = nil,
        configDrivenPreferredModels: Bool = false
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
        if let model {
            try await configurationService.store(
                model,
                for: ProviderConnectionService.modelKey(for: providerIdentity),
                at: .providerSettings
            )
        }
        let factory = RecordingAdapterFactory()
        let preferredModels: @Sendable (ProviderIdentity) async -> [ModelReference]
        if configDrivenPreferredModels {
            preferredModels = CompositionRoot.preferredModels(configurationService: configurationService)
        } else {
            preferredModels = { _ in [modelReference] }
        }
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: preferredModels,
            adapterFactory: { resolvedEndpoint, resolvedReference, kind in
                try await factory.make(endpoint: resolvedEndpoint, credential: resolvedReference, kind: kind)
            }
        )
        return (binding, factory, providerIdentity)
    }

    private func makeEmptyBinding() -> ProviderAdapterBinding {
        ProviderAdapterBinding(
            lifecycleService: ProviderLifecycleService(),
            configurationService: makeConfigurationService(),
            preferredModels: { _ in [modelReference] },
            adapterFactory: { _, _, _ in throw CapabilityError.providerUnavailable }
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
        XCTAssertEqual(factory.calls[0].kind, .openAICompatible)
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

    func testGenerateTextDoesNotOverwriteTheExplicitRequestModelWithConfiguredFallback() async throws {
        let combo = "omniroute:gpt-4o"
        let (binding, factory, _) = try await makeBinding(model: combo)
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        let response = try await binding.generateText(from: request)
        XCTAssertEqual(response.text, "generated reply")
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testSendMessageDoesNotOverwriteTheExplicitRequestModelWithConfiguredFallback() async throws {
        let combo = "omniroute:gpt-4o"
        let (binding, factory, _) = try await makeBinding(model: combo)
        let request = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference
        )
        let response = try await binding.sendMessage(request)
        XCTAssertEqual(response.message, Message(role: .assistant, content: "assistant reply"))
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testStreamDoesNotOverwriteTheExplicitRequestModelWithConfiguredFallback() async throws {
        let combo = "omniroute:gpt-4o"
        let (binding, factory, _) = try await makeBinding(model: combo)
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
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testGenerateTextServesTheRequestModelWhenNoModelIsRecorded() async throws {
        let (binding, factory, _) = try await makeBinding()
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        _ = try await binding.generateText(from: request)
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testSendMessageServesTheRequestModelWhenNoModelIsRecorded() async throws {
        let (binding, factory, _) = try await makeBinding()
        let request = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference
        )
        _ = try await binding.sendMessage(request)
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testStreamServesTheRequestModelWhenNoModelIsRecorded() async throws {
        let (binding, factory, _) = try await makeBinding()
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference
        )
        let stream = try await binding.stream(request)
        for try await _ in stream {}
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
    }

    func testGenerateTextServesTheRecordedModelWhenPreferredModelsAreConfigDriven() async throws {
        let combo = "omniroute:gpt-4o"
        let (binding, factory, _) = try await makeBinding(
            model: combo,
            configDrivenPreferredModels: true
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: ModelReference(name: combo)
        )
        let response = try await binding.generateText(from: request)
        XCTAssertEqual(response.text, "generated reply")
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.adapterModels, [combo])
    }

    func testStreamServesTheRecordedModelWhenPreferredModelsAreConfigDriven() async throws {
        let combo = "omniroute:gpt-4o"
        let (binding, factory, _) = try await makeBinding(
            model: combo,
            configDrivenPreferredModels: true
        )
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: ModelReference(name: combo)
        )
        let stream = try await binding.stream(request)
        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.adapterModels, [combo])
    }

    func testGenerateTextDoesNotInventADefaultModelWhenNoModelIsRecorded() async throws {
        let (binding, factory, _) = try await makeBinding(configDrivenPreferredModels: true)
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
        XCTAssertEqual(factory.calls.count, 0)
        XCTAssertEqual(factory.adapterModels, [])
    }

    func testThrowsProviderUnavailableWhenRequestingTheDefaultFromAComboProviderWithConfigDrivenPreferredModels() async throws {
        let (binding, _, _) = try await makeBinding(
            model: "omniroute:gpt-4o",
            configDrivenPreferredModels: true
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )
        await assertThrowsProviderUnavailable {
            _ = try await binding.generateText(from: request)
        }
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
            adapterFactory: { resolvedEndpoint, resolvedReference, kind in
                try await factory.make(endpoint: resolvedEndpoint, credential: resolvedReference, kind: kind)
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

    func testExplicitProviderRoutesSameNamedModelToThatProviderOnly() async throws {
        let first = ProviderIdentity()
        let second = ProviderIdentity()
        let lifecycle = ProviderLifecycleService()
        try await register(lifecycle, identity: first)
        try await register(lifecycle, identity: second)
        let configurationService = makeConfigurationService()
        for (identity, endpoint) in [
            (first, "https://first.example.com/v1"),
            (second, "https://second.example.com/v1"),
        ] {
            try await configurationService.store(
                endpoint,
                for: ProviderConnectionService.endpointKey(for: identity),
                at: .providerSettings
            )
            try await configurationService.store(
                CredentialReference(),
                for: ProviderConnectionService.credentialReferenceKey(for: identity),
                at: .providerSettings
            )
        }
        let factory = RecordingAdapterFactory()
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: { _ in [modelReference] },
            adapterFactory: { endpoint, credential, kind in
                try await factory.make(endpoint: endpoint, credential: credential, kind: kind)
            }
        )
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference,
            provider: second
        )

        let stream = try await binding.stream(request)
        for try await _ in stream {}

        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.calls[0].endpoint, URL(string: "https://second.example.com/v1"))
        XCTAssertEqual(factory.adapterModels, [modelReference.name])
        XCTAssertEqual(factory.capturedAdapter.streamingRequests.first?.provider, second)
    }

    func testRecordedAPIKindRoutesTheAdapterFamily() async throws {
        let providerIdentity = ProviderIdentity()
        let lifecycle = ProviderLifecycleService()
        try await register(lifecycle, identity: providerIdentity)
        let configurationService = makeConfigurationService()
        try await configurationService.store(
            "https://generativelanguage.googleapis.com/v1beta",
            for: ProviderConnectionService.endpointKey(for: providerIdentity),
            at: .providerSettings
        )
        try await configurationService.store(
            CredentialReference(),
            for: ProviderConnectionService.credentialReferenceKey(for: providerIdentity),
            at: .providerSettings
        )
        try await configurationService.store(
            ProviderAPIKind.gemini,
            for: ProviderConnectionService.apiKindKey(for: providerIdentity),
            at: .providerSettings
        )
        let factory = RecordingAdapterFactory()
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: { _ in [modelReference] },
            adapterFactory: { endpoint, credential, kind in
                try await factory.make(endpoint: endpoint, credential: credential, kind: kind)
            }
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )

        _ = try await binding.generateText(from: request)

        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.calls[0].kind, .gemini)
        XCTAssertEqual(
            factory.calls[0].endpoint,
            URL(string: "https://generativelanguage.googleapis.com/v1beta")
        )
    }

    func testProviderWithoutRecordedAPIKindResolvesTheOpenAICompatibleDefault() async throws {
        let providerIdentity = ProviderIdentity()
        let lifecycle = ProviderLifecycleService()
        try await register(lifecycle, identity: providerIdentity)
        let configurationService = makeConfigurationService()
        try await configurationService.store(
            "https://api.example.com/v1",
            for: ProviderConnectionService.endpointKey(for: providerIdentity),
            at: .providerSettings
        )
        try await configurationService.store(
            CredentialReference(),
            for: ProviderConnectionService.credentialReferenceKey(for: providerIdentity),
            at: .providerSettings
        )
        let factory = RecordingAdapterFactory()
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycle,
            configurationService: configurationService,
            preferredModels: { _ in [modelReference] },
            adapterFactory: { endpoint, credential, kind in
                try await factory.make(endpoint: endpoint, credential: credential, kind: kind)
            }
        )
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )

        _ = try await binding.generateText(from: request)

        XCTAssertEqual(factory.calls.count, 1)
        XCTAssertEqual(factory.calls[0].kind, .openAICompatible)
    }

    func testStreamForwardsResolvedAttachmentsAndHistoryToTheAdapter() async throws {
        let attachment = imageAttachment()
        let resolved = ResolvedAttachment(
            attachment: attachment,
            payload: .image(data: Data([1, 2, 3]), mediaType: "image/png")
        )
        let history = [
            Message(role: .system, content: "You are concise."),
            Message(role: .user, content: "Describe", attachments: [attachment]),
        ]
        let (binding, factory, _) = try await makeBinding()
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: history,
            model: modelReference,
            resolvedAttachments: [resolved]
        )

        let stream = try await binding.stream(request)
        for try await _ in stream {}

        let forwarded = try XCTUnwrap(factory.capturedAdapter.streamingRequests.first)
        XCTAssertEqual(forwarded.identity, request.identity)
        XCTAssertEqual(forwarded.history, history)
        XCTAssertEqual(forwarded.model, modelReference)
        XCTAssertEqual(forwarded.resolvedAttachments, [resolved])
    }

    func testSendMessageForwardsResolvedAttachmentsAndHistoryToTheAdapter() async throws {
        let attachment = imageAttachment()
        let resolved = ResolvedAttachment(
            attachment: attachment,
            payload: .image(data: Data([1, 2, 3]), mediaType: "image/png")
        )
        let history = [Message(role: .user, content: "Describe", attachments: [attachment])]
        let (binding, factory, _) = try await makeBinding()
        let request = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: history,
            model: modelReference,
            resolvedAttachments: [resolved]
        )

        _ = try await binding.sendMessage(request)

        let forwarded = try XCTUnwrap(factory.capturedAdapter.conversationRequests.first)
        XCTAssertEqual(forwarded.identity, request.identity)
        XCTAssertEqual(forwarded.history, history)
        XCTAssertEqual(forwarded.model, modelReference)
        XCTAssertEqual(forwarded.resolvedAttachments, [resolved])
    }

    func testExplicitProviderIsPreservedInTheForwardedRequests() async throws {
        let provider = ProviderIdentity()
        let (binding, factory, _) = try await makeBinding(providerIdentity: provider)
        let streaming = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference,
            provider: provider
        )
        let conversation = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: modelReference,
            provider: provider
        )
        let generation = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference,
            provider: provider
        )

        let stream = try await binding.stream(streaming)
        for try await _ in stream {}
        _ = try await binding.sendMessage(conversation)
        _ = try await binding.generateText(from: generation)

        XCTAssertEqual(factory.capturedAdapter.streamingRequests.first?.provider, provider)
        XCTAssertEqual(factory.capturedAdapter.conversationRequests.first?.provider, provider)
        XCTAssertEqual(factory.capturedAdapter.textRequests.first?.provider, provider)
    }

    func testTextOnlyRequestsAreForwardedUnchanged() async throws {
        let history = [Message(role: .user, content: "Hello")]
        let (binding, factory, _) = try await makeBinding()
        let streaming = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: history,
            model: modelReference
        )
        let conversation = ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: history,
            model: modelReference
        )
        let generation = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: modelReference
        )

        let stream = try await binding.stream(streaming)
        for try await _ in stream {}
        _ = try await binding.sendMessage(conversation)
        _ = try await binding.generateText(from: generation)

        XCTAssertEqual(factory.capturedAdapter.streamingRequests, [streaming])
        XCTAssertEqual(factory.capturedAdapter.conversationRequests, [conversation])
        XCTAssertEqual(factory.capturedAdapter.textRequests, [generation])
    }

    private func imageAttachment() -> MessageAttachment {
        MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "photo.png",
            mediaType: "image/png",
            kind: .image,
            byteCount: 3,
            storageKey: "opaque-key.png"
        )
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
        _ = try await first.composition.providerConnectionService.configure(
            makeConfigureRequest(),
            endpoint: "https://api.example.com/v1",
            model: modelReference.name
        )
        let second = try await AppLaunch(storageRoot: root)
        let selection = await second.composition.selectionService.select(requiredCapability: .streaming)
        guard case .selected(provider: _, model: let model) = selection else {
            return XCTFail("Expected a selected provider after relaunch")
        }
        XCTAssertEqual(model, modelReference)
    }
}

// MARK: - LaunchFailureCopy

final class LaunchFailureCopyTests: XCTestCase {
    func testRepositoryFailure_MapsToConciseMessage() {
        let message = LaunchFailureCopy.message(for: RepositoryError.storageUnavailable)
        XCTAssertEqual(message, "Storage is temporarily unavailable. Please try again.")
        XCTAssertFalse(message.contains("storageUnavailable"))
    }

    func testProviderLifecycleFailure_MapsToConciseMessage() {
        let invalid = LaunchFailureCopy.message(
            for: ProviderLifecycleError.invalidTransition(from: .registered, to: .ready)
        )
        XCTAssertEqual(invalid, "A configured provider could not be prepared. Please try again.")
        let missing = LaunchFailureCopy.message(
            for: ProviderLifecycleError.providerNotFound(identity: ProviderIdentity())
        )
        XCTAssertEqual(missing, "A configured provider could not be prepared. Please try again.")
    }

    func testCredentialStorageFailure_MapsToConciseMessage() {
        let missing = LaunchFailureCopy.message(for: CredentialStorageError.credentialNotFound)
        XCTAssertEqual(missing, "The stored credential could not be found. Check your connection settings.")
        let unavailable = LaunchFailureCopy.message(for: CredentialStorageError.storageUnavailable)
        XCTAssertEqual(unavailable, "Secure credential storage is unavailable. Please try again.")
    }

    func testValidationFailure_PreservesTheReason() {
        let message = LaunchFailureCopy.message(
            for: ApplicationValidationError.invalid(reason: "The workspace is not stored.")
        )
        XCTAssertEqual(message, "The workspace is not stored.")
    }

    func testUnknownError_MapsToGenericFallback() {
        struct UnknownLaunchError: Error {}
        let message = LaunchFailureCopy.message(for: UnknownLaunchError())
        XCTAssertEqual(message, "Omnia couldn't be launched. Please try again.")
    }

    func testMessage_NeverPresentsRawErrorDetail() {
        let error = RepositoryError.storageUnavailable
        let message = LaunchFailureCopy.message(for: error)
        XCTAssertNotEqual(message, String(describing: error))
    }
}
