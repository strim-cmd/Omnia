package com.omnia.app

import com.omnia.application.ConfigureProviderRequest
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.application.ConversationService
import com.omnia.application.ProviderConnectionService
import com.omnia.application.ProviderModelService
import com.omnia.application.SendMessageUseCase
import com.omnia.common.SemanticVersion
import com.omnia.common.SingleDispatcherProvider
import com.omnia.data.configuration.ConfigurationBootstrap
import com.omnia.data.configuration.FileConfigurationRepository
import com.omnia.data.conversation.FileConversationRepository
import com.omnia.data.provider.FileProviderRepository
import com.omnia.data.workspace.FileWorkspaceRepository
import com.omnia.domain.Capability
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class ChatProviderPipelineRegressionTest {

    private lateinit var tempDir: File
    private lateinit var configRepo: FileConfigurationRepository
    private lateinit var providerRepo: FileProviderRepository
    private lateinit var credentialStorage: FakeCredentialStorage

    @Before
    fun setup() {
        ConfigurationBootstrap.resetForTesting()
        ConfigurationBootstrap.ensureRegistered()
        tempDir = Files.createTempDirectory("ChatPipelineRegression").toFile()
        configRepo = FileConfigurationRepository(File(tempDir, "config"))
        providerRepo = FileProviderRepository(File(tempDir, "providers"))
        credentialStorage = FakeCredentialStorage()
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    private fun buildServiceGraph(): ProviderConnectionService {
        val lifecycleService = ProviderLifecycleService()
        return ProviderConnectionService(
            providerRepository = providerRepo,
            credentialStorage = credentialStorage,
            configurationRepository = configRepo,
            lifecycleService = lifecycleService,
        )
    }

    private fun buildCandidateProvider(
        service: ProviderConnectionService,
        name: String,
        model: String,
        apiKind: ProviderAPIKind = ProviderAPIKind.openAICompatible,
    ): ProviderIdentity {
        val request = ConfigureProviderRequest(
            displayName = name,
            capabilities = com.omnia.domain.ProviderCapabilities(
                setOf(Capability.textGeneration, Capability.streaming, Capability.conversation)
            ),
            limits = com.omnia.domain.ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
            credential = Credential.of("test-key-$name"),
        )
        return runBlocking {
            val provider = service.configure(
                request,
                endpoint = "https://api.example.com/v1",
                model = model,
                apiKind = apiKind,
            )
            provider.identity
        }
    }

    @Test
    fun candidatesFor_openAI_containsProviderAndModel() = runBlocking {
        val service = buildServiceGraph()
        val identity = buildCandidateProvider(service, "OpenAI", "gpt-4")

        val lifecycleService = ProviderLifecycleService()
        val configurationService = com.omnia.application.ConfigurationService(configRepo)
        val modelService = ProviderModelService(
            configurationService,
            lifecycleService,
            configuredModel = { id ->
                val name = configurationService.resolved<String>(ProviderConnectionService.modelKey(id))
                name?.let { ModelReference(it) }
            },
        )

        val candidatesFor: suspend (Capability) -> List<ProviderCandidate> = { capability ->
            service.allProviders()
                .filter { it.state == com.omnia.domain.ProviderState.ready && it.canDeliver(capability) }
                .mapNotNull { provider ->
                    val catalog = modelService.cachedCatalog(provider.identity)
                    if (catalog.models.isEmpty()) null
                    else ProviderCandidate(provider = provider.identity, models = catalog.models)
                }
        }

        val candidates = candidatesFor(Capability.streaming)
        assertTrue("Should have at least one candidate", candidates.isNotEmpty())
        val found = candidates.find { it.provider == identity }
        assertNotNull("Provider should be in candidates", found)
        assertTrue("Model should be in candidate's model list",
            found!!.models.any { it.name == "gpt-4" })
    }

    @Test
    fun candidatesFor_gemini_containsProviderAndModel() = runBlocking {
        val service = buildServiceGraph()
        val identity = buildCandidateProvider(service, "Gemini", "gemini-pro", ProviderAPIKind.gemini)

        val lifecycleService = ProviderLifecycleService()
        val configurationService = com.omnia.application.ConfigurationService(configRepo)
        val modelService = ProviderModelService(
            configurationService,
            lifecycleService,
            configuredModel = { id ->
                val name = configurationService.resolved<String>(ProviderConnectionService.modelKey(id))
                name?.let { ModelReference(it) }
            },
        )

        val candidatesFor: suspend (Capability) -> List<ProviderCandidate> = { capability ->
            service.allProviders()
                .filter { it.state == com.omnia.domain.ProviderState.ready && it.canDeliver(capability) }
                .mapNotNull { provider ->
                    val catalog = modelService.cachedCatalog(provider.identity)
                    if (catalog.models.isEmpty()) null
                    else ProviderCandidate(provider = provider.identity, models = catalog.models)
                }
        }

        val candidates = candidatesFor(Capability.streaming)
        assertTrue("Should have at least one candidate", candidates.isNotEmpty())
        val found = candidates.find { it.provider == identity }
        assertNotNull("Gemini provider should be in candidates", found)
        assertTrue("Model should be in candidate's model list",
            found!!.models.any { it.name == "gemini-pro" })
    }

    @Test
    fun candidatesFor_persistsAcrossGraphRecreation() = runBlocking {
        val service = buildServiceGraph()
        val identity = buildCandidateProvider(service, "Recreated", "recreated-model")

        val newConfigRepo = FileConfigurationRepository(File(tempDir, "config"))
        val newProviderRepo = FileProviderRepository(File(tempDir, "providers"))
        val newService = ProviderConnectionService(
            providerRepository = newProviderRepo,
            credentialStorage = credentialStorage,
            configurationRepository = newConfigRepo,
            lifecycleService = ProviderLifecycleService(),
        )

        val lifecycleService = ProviderLifecycleService()
        val configurationService = com.omnia.application.ConfigurationService(newConfigRepo)
        val modelService = ProviderModelService(
            configurationService,
            lifecycleService,
            configuredModel = { id ->
                val name = configurationService.resolved<String>(ProviderConnectionService.modelKey(id))
                name?.let { ModelReference(it) }
            },
        )

        val candidatesFor: suspend (Capability) -> List<ProviderCandidate> = { capability ->
            newService.allProviders()
                .filter { it.state == com.omnia.domain.ProviderState.ready && it.canDeliver(capability) }
                .mapNotNull { provider ->
                    val catalog = modelService.cachedCatalog(provider.identity)
                    if (catalog.models.isEmpty()) null
                    else ProviderCandidate(provider = provider.identity, models = catalog.models)
                }
        }

        val candidates = candidatesFor(Capability.streaming)
        val found = candidates.find { it.provider == identity }
        assertNotNull("Provider should survive graph recreation", found)
        assertTrue("Model should survive graph recreation",
            found!!.models.any { it.name == "recreated-model" })
    }

    @Test
    fun streamingContentDeltaAndCompletion_updatesUseCase() = runBlocking {
        val service = buildServiceGraph()
        val identity = buildCandidateProvider(service, "StreamTest", "stream-model")

        val lifecycleService = ProviderLifecycleService()
        val configurationService = com.omnia.application.ConfigurationService(configRepo)
        val modelService = ProviderModelService(
            configurationService,
            lifecycleService,
            configuredModel = { id ->
                val name = configurationService.resolved<String>(ProviderConnectionService.modelKey(id))
                name?.let { ModelReference(it) }
            },
        )

        val convRepo = FakeConvRepository()
        val conv = Conversation(
            identity = ConversationIdentity("test-conv"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        convRepo.save(conv)

        val streamingContract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> = flowOf(
                StreamingUpdate.ContentDelta(request.identity, "Hello"),
                StreamingUpdate.ContentDelta(request.identity, " world"),
                StreamingUpdate.Completion(
                    request.identity,
                    Message(MessageRole.assistant, "Hello world"),
                ),
            )
        }

        val useCase = SendMessageUseCase(
            streamingContract = streamingContract,
            selectionPolicy = ProviderSelectionPolicy(),
            conversationRepository = convRepo,
            candidatesFor = { capability ->
                service.allProviders()
                    .filter { it.state == com.omnia.domain.ProviderState.ready && it.canDeliver(capability) }
                    .mapNotNull { provider ->
                        val catalog = modelService.cachedCatalog(provider.identity)
                        if (catalog.models.isEmpty()) null
                        else ProviderCandidate(provider = provider.identity, models = catalog.models)
                    }
            },
        )

        val request = com.omnia.application.SendMessageRequest(
            conversation = ConversationIdentity("test-conv"),
            message = Message(role = MessageRole.user, content = "Hi"),
            modelSelection = ProviderModelSelection(identity, ModelReference("stream-model")),
        )

        val updates = useCase.send(request).toList()
        assertTrue("Should have ContentDelta updates",
            updates.any { it is StreamingUpdate.ContentDelta })
        assertTrue("Should have Completion update",
            updates.any { it is StreamingUpdate.Completion })

        val stored = convRepo.get("test-conv")!!
        assertTrue("Assistant message should be persisted",
            stored.history.any { it.role == MessageRole.assistant && it.content == "Hello world" })
    }

    private class FakeConvRepository : com.omnia.domain.ConversationRepository {
        private val store = mutableMapOf<String, Conversation>()
        override suspend fun save(conversation: Conversation) { store[conversation.identity.id] = conversation }
        override suspend fun conversation(identity: ConversationIdentity): Conversation? = store[identity.id]
        override suspend fun delete(identity: ConversationIdentity) { store.remove(identity.id) }
        override suspend fun allConversations(): List<Conversation> = store.values.toList()
        fun get(id: String): Conversation? = store[id]
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
