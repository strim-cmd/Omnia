package com.omnia.app

import com.omnia.application.ConfigureProviderRequest
import com.omnia.application.ConversationService
import com.omnia.application.ProviderConnectionService
import com.omnia.application.ProviderModelService
import com.omnia.application.SendMessageRequest
import com.omnia.application.SendMessageUseCase
import com.omnia.common.SemanticVersion
import com.omnia.data.configuration.ConfigurationBootstrap
import com.omnia.data.configuration.FileConfigurationRepository
import com.omnia.data.conversation.FileConversationRepository
import com.omnia.data.provider.FileProviderRepository
import com.omnia.data.workspace.FileWorkspaceRepository
import com.omnia.domain.Capability
import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ConversationRepository
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderCandidate
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.ProviderSelectionPolicy
import com.omnia.domain.StreamingContract
import com.omnia.domain.StreamingRequest
import com.omnia.domain.StreamingUpdate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class ModelSelectionRegressionTest {

    private lateinit var tempDir: File
    private lateinit var configRepo: FileConfigurationRepository
    private lateinit var providerRepo: FileProviderRepository
    private lateinit var credentialStorage: FakeCredentialStorage

    @Before
    fun setup() {
        ConfigurationBootstrap.resetForTesting()
        ConfigurationBootstrap.ensureRegistered()
        tempDir = Files.createTempDirectory("ModelSelectionRegression").toFile()
        configRepo = FileConfigurationRepository(File(tempDir, "config"))
        providerRepo = FileProviderRepository(File(tempDir, "providers"))
        credentialStorage = FakeCredentialStorage()
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    private fun buildProviderConnectionService(): ProviderConnectionService =
        ProviderConnectionService(
            providerRepository = providerRepo,
            credentialStorage = credentialStorage,
            configurationRepository = configRepo,
            lifecycleService = ProviderLifecycleService(),
        )

    private fun buildProviderModelService(
        connectionService: ProviderConnectionService,
    ): ProviderModelService {
        val lifecycleService = ProviderLifecycleService()
        val configurationService = com.omnia.application.ConfigurationService(configRepo)
        return ProviderModelService(
            configurationService,
            lifecycleService,
            configuredModel = { id ->
                val name = configurationService.resolved<String>(ProviderConnectionService.modelKey(id))
                name?.let { ModelReference(it) }
            },
        )
    }

    private fun buildConversationService(
        modelService: ProviderModelService,
        conversationRepository: ConversationRepository = FileConversationRepository(File(tempDir, "conversations")),
        workspaceRepository: FileWorkspaceRepository = FileWorkspaceRepository(File(tempDir, "workspaces")),
    ): ConversationService = ConversationService(
        conversationRepository = conversationRepository,
        workspaceRepository = workspaceRepository,
        defaultModelSelection = { modelService.defaultSelection() },
    )

    private fun configureProvider(
        service: ProviderConnectionService,
        name: String,
        model: String,
        apiKind: ProviderAPIKind = ProviderAPIKind.openAICompatible,
    ): ProviderIdentity = runBlocking {
        val request = ConfigureProviderRequest(
            displayName = name,
            credential = Credential.of("test-key-$name"),
            capabilities = com.omnia.domain.ProviderCapabilities(
                setOf(Capability.textGeneration, Capability.streaming, Capability.conversation)
            ),
            limits = com.omnia.domain.ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
        )
        val provider = service.configure(
            request,
            endpoint = "https://api.example.com/v1",
            model = model,
            apiKind = apiKind,
        )
        provider.identity
    }

    private fun buildCandidatesFor(
        connectionService: ProviderConnectionService,
        modelService: ProviderModelService,
    ): suspend (Capability) -> List<ProviderCandidate> = { capability ->
        connectionService.allProviders()
            .filter { it.state == com.omnia.domain.ProviderState.ready && it.canDeliver(capability) }
            .mapNotNull { provider ->
                val catalog = modelService.cachedCatalog(provider.identity)
                if (catalog.models.isEmpty()) null
                else ProviderCandidate(provider = provider.identity, models = catalog.models)
            }
    }

    private fun buildSendMessageUseCase(
        connectionService: ProviderConnectionService,
        modelService: ProviderModelService,
        conversationRepository: ConversationRepository,
        streamingContract: StreamingContract = RecordingStreamingContract(),
    ): SendMessageUseCase = SendMessageUseCase(
        streamingContract = streamingContract,
        selectionPolicy = ProviderSelectionPolicy(),
        conversationRepository = conversationRepository,
        candidatesFor = buildCandidatesFor(connectionService, modelService),
    )

    @Test
    fun defaultSelection_newConversationPicksItUp() = runBlocking {
        val connectionService = buildProviderConnectionService()
        val identity = configureProvider(connectionService, "OmniRoute", "omnia-coding")
        val modelService = buildProviderModelService(connectionService)

        modelService.setDefaultSelection(
            ProviderModelSelection(provider = identity, model = ModelReference("omnia-coding"))
        )

        val convService = buildConversationService(modelService)
        val conversation = convService.createConversation()

        assertNotNull("conversation should have a modelSelection", conversation.modelSelection)
        assertEquals("provider should match", identity, conversation.modelSelection!!.provider)
        assertEquals("model should match", "omnia-coding", conversation.modelSelection!!.model.name)
    }

    @Test
    fun explicitModel_wiresThroughSendMessageToStreamingRequest() = runBlocking {
        val connectionService = buildProviderConnectionService()
        val identity = configureProvider(connectionService, "TestProvider", "test-model")
        val modelService = buildProviderModelService(connectionService)
        val convRepo = FileConversationRepository(File(tempDir, "conversations"))
        val convService = buildConversationService(modelService, convRepo)
        val conversation = convService.createConversation()

        val capturedRequests = mutableListOf<StreamingRequest>()
        val streamingContract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
                capturedRequests.add(request)
                return flowOf(
                    StreamingUpdate.Completion(
                        request.identity,
                        Message(MessageRole.assistant, "ok"),
                    ),
                )
            }
        }

        val useCase = buildSendMessageUseCase(connectionService, modelService, convRepo, streamingContract)
        val sendRequest = SendMessageRequest(
            conversation = conversation.identity,
            message = Message(role = MessageRole.user, content = "Hello"),
            modelSelection = ProviderModelSelection(provider = identity, model = ModelReference("test-model")),
        )
        useCase.send(sendRequest).toList()

        assertEquals("Should capture exactly one streaming request", 1, capturedRequests.size)
        val captured = capturedRequests[0]
        assertNotNull("Streaming request should have a resolved provider", captured.provider)
        assertEquals(
            "Wire request model should be test-model",
            "test-model",
            captured.model.name,
        )
    }

    @Test
    fun defaultSelection_persistsAcrossServiceRecreation() = runBlocking {
        val connectionService = buildProviderConnectionService()
        val identity = configureProvider(connectionService, "PersistentProvider", "persist-model")
        val modelService = buildProviderModelService(connectionService)

        modelService.setDefaultSelection(
            ProviderModelSelection(provider = identity, model = ModelReference("persist-model"))
        )

        val newConfigRepo = FileConfigurationRepository(File(tempDir, "config"))
        val newProviderRepo = FileProviderRepository(File(tempDir, "providers"))
        val newConnectionService = ProviderConnectionService(
            providerRepository = newProviderRepo,
            credentialStorage = credentialStorage,
            configurationRepository = newConfigRepo,
            lifecycleService = ProviderLifecycleService(),
        )
        val newModelService = buildProviderModelService(newConnectionService)

        val restored = newModelService.defaultSelection()
        assertNotNull("Default selection should survive recreation", restored)
        assertEquals("Provider should match", identity, restored!!.provider)
        assertEquals("Model should match", "persist-model", restored.model.name)

        val newConvService = buildConversationService(newModelService)
        val conversation = newConvService.createConversation()
        assertEquals("New conversation should use restored default", "persist-model", conversation.modelSelection?.model?.name)
    }

    @Test
    fun perConversationModel_overridesDefaultInSendMessage() = runBlocking {
        val connectionService = buildProviderConnectionService()
        val providerA = configureProvider(connectionService, "ProviderA", "model-a")
        val providerB = configureProvider(connectionService, "ProviderB", "model-b")
        val modelService = buildProviderModelService(connectionService)

        modelService.setDefaultSelection(
            ProviderModelSelection(provider = providerA, model = ModelReference("model-a"))
        )

        val convRepo = FileConversationRepository(File(tempDir, "conversations"))
        val convService = buildConversationService(modelService, convRepo)
        val conversation = convService.createConversation()

        convService.selectModel(
            selection = ProviderModelSelection(provider = providerB, model = ModelReference("model-b")),
            conversationIdentity = conversation.identity,
        )

        val capturedRequests = mutableListOf<StreamingRequest>()
        val streamingContract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
                capturedRequests.add(request)
                return flowOf(
                    StreamingUpdate.Completion(
                        request.identity,
                        Message(MessageRole.assistant, "ok"),
                    ),
                )
            }
        }

        val useCase = buildSendMessageUseCase(connectionService, modelService, convRepo, streamingContract)
        val updated = convRepo.conversation(conversation.identity)!!
        val sendRequest = SendMessageRequest(
            conversation = updated.identity,
            message = Message(role = MessageRole.user, content = "Hello"),
            modelSelection = updated.modelSelection,
        )
        useCase.send(sendRequest).toList()

        assertEquals(1, capturedRequests.size)
        val captured = capturedRequests[0]
        assertNotNull("Provider should be resolved", captured.provider)
        assertEquals(
            "Wire request model should be model-b (per-conversation override)",
            "model-b",
            captured.model.name,
        )
    }

    @Test
    fun explicitModel_survivesRecreation_sendUsesStoredSelection() = runBlocking {
        val connectionService = buildProviderConnectionService()
        val identity = configureProvider(connectionService, "SurvivalProvider", "survive-model")
        val modelService = buildProviderModelService(connectionService)
        modelService.setDefaultSelection(
            ProviderModelSelection(provider = identity, model = ModelReference("survive-model"))
        )

        val convRepo = FileConversationRepository(File(tempDir, "conversations"))
        val convService = buildConversationService(modelService, convRepo)
        val conversation = convService.createConversation()

        val newConfigRepo = FileConfigurationRepository(File(tempDir, "config"))
        val newProviderRepo = FileProviderRepository(File(tempDir, "providers"))
        val newConnectionService = ProviderConnectionService(
            providerRepository = newProviderRepo,
            credentialStorage = credentialStorage,
            configurationRepository = newConfigRepo,
            lifecycleService = ProviderLifecycleService(),
        )
        val newModelService = buildProviderModelService(newConnectionService)
        val newConvRepo = FileConversationRepository(File(tempDir, "conversations"))
        val loadedConv = newConvRepo.conversation(conversation.identity)
        assertNotNull("Conversation should be persisted and reloadable", loadedConv)
        assertEquals("Model selection should survive", "survive-model", loadedConv!!.modelSelection?.model?.name)

        val capturedRequests = mutableListOf<StreamingRequest>()
        val streamingContract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
                capturedRequests.add(request)
                return flowOf(
                    StreamingUpdate.Completion(
                        request.identity,
                        Message(MessageRole.assistant, "ok"),
                    ),
                )
            }
        }

        val useCase = buildSendMessageUseCase(newConnectionService, newModelService, newConvRepo, streamingContract)
        val sendRequest = SendMessageRequest(
            conversation = loadedConv.identity,
            message = Message(role = MessageRole.user, content = "Hello"),
            modelSelection = loadedConv.modelSelection,
        )
        useCase.send(sendRequest).toList()

        assertEquals(1, capturedRequests.size)
        assertEquals(
            "Wire request model should be survive-model after recreation",
            "survive-model",
            capturedRequests[0].model.name,
        )
    }

    private class RecordingStreamingContract : StreamingContract {
        val requests = mutableListOf<StreamingRequest>()
        override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
            requests.add(request)
            return flowOf(
                StreamingUpdate.Completion(
                    request.identity,
                    Message(MessageRole.assistant, "ok"),
                ),
            )
        }
    }

    private class FakeCredentialStorage : CredentialStorageProtocol {
        val stores = mutableMapOf<String, Credential>()
        override suspend fun store(credential: Credential, reference: CredentialReference) {
            stores[reference.id] = credential
        }
        override suspend fun credential(reference: CredentialReference): Credential =
            stores[reference.id] ?: throw com.omnia.domain.CredentialStorageError.CredentialNotFound
        override suspend fun removeCredential(reference: CredentialReference) {
            stores.remove(reference.id)
        }
    }
}
