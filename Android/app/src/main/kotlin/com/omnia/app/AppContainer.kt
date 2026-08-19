package com.omnia.app

import android.content.Context
import com.omnia.application.AppMetadata
import com.omnia.application.AttachmentService
import com.omnia.application.ConfigurationService
import com.omnia.application.ConversationDraftService
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.application.ConversationService
import com.omnia.application.ProvideAppMetadata
import com.omnia.application.ProviderConnectionService
import com.omnia.application.ProviderModelService
import com.omnia.application.ProviderValidationService
import com.omnia.application.SendMessageUseCase
import com.omnia.common.Clock
import com.omnia.common.DispatcherProvider
import com.omnia.common.IdentifierFactory
import com.omnia.common.LogLevel
import com.omnia.common.Logger
import com.omnia.common.RandomIdentifierFactory
import com.omnia.common.SystemClock
import com.omnia.data.StorageLayout
import com.omnia.data.configuration.ConfigurationBootstrap
import com.omnia.data.configuration.FileConfigurationRepository
import com.omnia.data.conversation.FileConversationRepository
import com.omnia.data.attachment.FileAttachmentStorage
import com.omnia.data.provider.FileProviderRepository
import com.omnia.data.workspace.FileWorkspaceRepository
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderSelectionPolicy
import com.omnia.feature.chat.ChatDependencies
import com.omnia.feature.providers.ProvidersDependencies
import com.omnia.feature.settings.DataManagementService
import com.omnia.feature.settings.SettingsDependencies
import com.omnia.feature.settings.ThemeController
import com.omnia.network.adapters.GeminiProviderInspector
import com.omnia.network.adapters.OpenAICompatibleProviderInspector
import com.omnia.network.transport.OkHttpProviderTransport
import com.omnia.network.transport.ProviderTransport
import com.omnia.security.SecureCredentialStorage
import com.omnia.security.InMemoryCredentialStorage

class AppContainer(
    context: Context,
    testCredentialStorage: CredentialStorageProtocol? = null,
    testTransport: ProviderTransport? = null,
) {

    val clock: Clock = SystemClock()
    val identifierFactory: IdentifierFactory = RandomIdentifierFactory()
    val logger: Logger = AndroidLogger(minLevel = LogLevel.INFO)
    val dispatchers: DispatcherProvider = AndroidDispatchers()

    val appMetadata: AppMetadata = AppMetadata(
        name = "Omnia",
        marketingVersion = "1.0.0",
        buildNumber = "1",
    )
    val provideAppMetadata: ProvideAppMetadata = ProvideAppMetadata(appMetadata)

    val themeController: ThemeController = AppThemeController()

    private val storageLayout = StorageLayout.forFilesDir(context.filesDir).also { it.ensureDirectories() }

    val providerRepository = FileProviderRepository(storageLayout.providersDir)
    val conversationRepository = FileConversationRepository(storageLayout.conversationsDir)
    val configurationRepository = FileConfigurationRepository(storageLayout.configurationDir).also {
        ConfigurationBootstrap.ensureRegistered()
    }
    val workspaceRepository = FileWorkspaceRepository(storageLayout.workspacesDir)
    val credentialStorage: CredentialStorageProtocol = testCredentialStorage
        ?: try { SecureCredentialStorage(context) } catch (_: Exception) { InMemoryCredentialStorage() }
    val lifecycleService = ProviderLifecycleService()
    val configurationService = ConfigurationService(configurationRepository)

    val providerConnectionService = ProviderConnectionService(
        providerRepository,
        credentialStorage,
        configurationRepository,
        lifecycleService,
    )

    val transport: ProviderTransport = testTransport
        ?: try { OkHttpProviderTransport() } catch (_: Exception) { throw IllegalStateException("Transport unavailable") }

    val adapterFactory = DefaultAdapterFactory(transport, credentialStorage)

    val providerAdapterBinding = ProviderAdapterBinding(
        providerRepository,
        configurationService,
        adapterFactory,
    )

    val providerModelService = ProviderModelService(
        configurationService,
        lifecycleService,
        configuredModel = { identity ->
            val name: String? = configurationService.resolved(ProviderConnectionService.modelKey(identity))
            name?.let { ModelReference(it) }
        },
        discoverModels = { identity ->
            val endpoint = configurationService.resolved<String>(
                ProviderConnectionService.endpointKey(identity)
            )
            val credentialRef = configurationService.resolved<CredentialReference>(
                ProviderConnectionService.credentialReferenceKey(identity)
            )
            val apiKind = configurationService.resolved<ProviderAPIKind>(
                ProviderConnectionService.apiKindKey(identity)
            ) ?: ProviderAPIKind.openAICompatible
            if (endpoint != null && credentialRef != null) {
                val inspector = when (apiKind) {
                    ProviderAPIKind.openAICompatible -> OpenAICompatibleProviderInspector(transport, credentialStorage, endpoint, credentialRef)
                    ProviderAPIKind.gemini -> GeminiProviderInspector(transport, credentialStorage, endpoint, credentialRef)
                }
                inspector.discoverModels()
            } else {
                emptyList()
            }
        },
    )

    val providerValidationService = ProviderValidationService(
        testCandidate = { endpoint, credential, model, apiKind ->
            val inspector = when (apiKind) {
                ProviderAPIKind.openAICompatible -> OpenAICompatibleProviderInspector(transport, endpoint, credential)
                ProviderAPIKind.gemini -> GeminiProviderInspector(transport, endpoint, credential)
            }
            inspector.testConnection(model)
        },
        testExisting = { identity, endpoint, model, apiKind ->
            val credentialRef = configurationService.resolved<CredentialReference>(
                ProviderConnectionService.credentialReferenceKey(identity)
            ) ?: throw com.omnia.domain.CapabilityError.ProviderUnavailable
            val inspector = when (apiKind) {
                ProviderAPIKind.openAICompatible -> OpenAICompatibleProviderInspector(transport, credentialStorage, endpoint, credentialRef)
                ProviderAPIKind.gemini -> GeminiProviderInspector(transport, credentialStorage, endpoint, credentialRef)
            }
            inspector.testConnection(model)
        },
    )

    val conversationService = ConversationService(
        conversationRepository,
        workspaceRepository,
        defaultModelSelection = { null },
        cleanupAttachments = { },
    )

    val conversationDraftService = ConversationDraftService(configurationService)

    val generationCoordinator = ConversationGenerationCoordinator(dispatchers)

    val attachmentStorage: com.omnia.domain.AttachmentStorageProtocol = FileAttachmentStorage(
        directory = storageLayout.attachmentsDir,
    )

    val attachmentService = AttachmentService(
        storage = attachmentStorage,
    )

    val sendMessageUseCase = SendMessageUseCase(
        streamingContract = providerAdapterBinding,
        selectionPolicy = ProviderSelectionPolicy(),
        conversationRepository = conversationRepository,
    )

    val chatDependencies: ChatDependencies = object : ChatDependencies {
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
        override val conversationService: ConversationService get() = this@AppContainer.conversationService
        override val conversationDraftService: ConversationDraftService get() = this@AppContainer.conversationDraftService
        override val conversationGenerationCoordinator: ConversationGenerationCoordinator get() = this@AppContainer.generationCoordinator
        override val providerModelService: ProviderModelService get() = this@AppContainer.providerModelService
        override val sendMessageUseCase: SendMessageUseCase get() = this@AppContainer.sendMessageUseCase
        override val attachmentService: AttachmentService get() = this@AppContainer.attachmentService
    }

    val providersDependencies: ProvidersDependencies = object : ProvidersDependencies {
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
        override val providerConnectionService: ProviderConnectionService get() = this@AppContainer.providerConnectionService
        override val providerModelService: ProviderModelService get() = this@AppContainer.providerModelService
        override val providerValidationService: ProviderValidationService get() = this@AppContainer.providerValidationService
    }

    val dataManagementService: DataManagementService = DataManagementService {
        val providers = providerConnectionService.allProviders()
        providers.forEach { providerConnectionService.remove(it.identity) }
        val conversations = conversationService.conversations()
        conversations.forEach { conversationService.delete(it.identity) }
    }

    val settingsDependencies: SettingsDependencies = object : SettingsDependencies {
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
        override val themeController: ThemeController get() = this@AppContainer.themeController
        override val dataManagementService: DataManagementService get() = this@AppContainer.dataManagementService
    }
}
