import Foundation
import OmniaApplication

/// Localized strings for the presentation layer (UX audit A5).
///
/// Consolidates all user-visible strings into a localization catalog.
/// Follows UI.md §Localization and ARC-005.
public enum Localized {
    /// Resolves presentation copy from this Swift package's resource bundle.
    /// Looking in the process main bundle causes package keys to leak into the
    /// UI when OmniaPresentation is consumed by the app.
    private static func localized(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }

    public static var about: String { localized("about") }
    public static var active: String { localized("active") }
    public static var activeProvider: String { localized("active_provider") }
    public static var addConnection: String { localized("add_connection") }
    public static var addProvider: String { localized("add_provider") }
    public static var addFirstProvider: String { localized("add_first_provider") }
    public static var addFirstProviderDescription: String {
        localized("add_first_provider_description")
    }
    public static var allProviders: String { localized("all_providers") }
    public static var apiKey: String { localized("api_key") }
    public static var appearance: String { localized("appearance") }
    public static var assistantIsResponding: String { localized("assistant_is_responding") }
    public static var attachment: String { localized("attachment") }
    public static var addPhotos: String { localized("add_photos") }
    public static var addFiles: String { localized("add_files") }
    public static var audio: String { localized("audio") }
    public static var automatic: String { localized("automatic") }
    public static var cancel: String { localized("cancel") }
    public static var capabilities: String { localized("capabilities") }
    public static var clearSearch: String { localized("clear_search") }
    public static var clearData: String { localized("clear_data") }
    public static var clearDataConfirmation: String { localized("clear_data_confirmation") }
    public static var clearDataScope: String { localized("clear_data_scope") }
    public static var code: String { localized("code") }
    public static var configuration: String { localized("configuration") }
    public static var connection: String { localized("connection") }
    public static var testConnection: String { localized("test_connection") }
    public static var testingConnection: String { localized("testing_connection") }
    public static var connectionInvalidCredential: String { localized("connection_invalid_credential") }
    public static var connectionUnreachable: String { localized("connection_unreachable") }
    public static var connectionInvalidEndpoint: String { localized("connection_invalid_endpoint") }
    public static var connectionModelUnavailable: String { localized("connection_model_unavailable") }
    public static var connectionRateLimited: String { localized("connection_rate_limited") }
    public static var connectionTimedOut: String { localized("connection_timed_out") }
    public static var connectionServerFailure: String { localized("connection_server_failure") }
    public static var connectionInvalidResponse: String { localized("connection_invalid_response") }
    public static var continueResponse: String { localized("continue_response") }
    public static func connectionTestSucceeded(_ count: Int) -> String {
        String(format: localized("connection_test_succeeded"), count)
    }
    public static var conversation: String { localized("conversation") }
    public static var conversationTitle: String { localized("conversation_title") }
    public static var conversations: String { localized("conversations") }
    public static var copy: String { localized("copy") }
    public static var copied: String { localized("copied") }
    public static var copyCode: String { localized("copy_code") }
    public static var copyCodeHint: String { localized("copy_code_hint") }
    public static var changeModel: String { localized("change_model") }
    public static var credentialNotFound: String { localized("credential_not_found") }
    public static var credentialStorageUnavailable: String { localized("credential_storage_unavailable") }
    public static var darkMode: String { localized("dark_mode") }
    public static var data: String { localized("data") }
    public static var defaultModel: String { localized("default_model") }
    public static var selectDefaultModel: String { localized("select_default_model") }
    public static var invalidDefaultModel: String { localized("invalid_default_model") }
    public static var delete: String { localized("delete") }
    public static var deleteConversation: String { localized("delete_conversation") }
    public static var deleteConversationConfirmation: String { localized("delete_conversation_confirmation") }
    public static var disabled: String { localized("disabled") }
    public static var dismiss: String { localized("dismiss") }
    public static var dislike: String { localized("dislike") }
    public static var displayName: String { localized("display_name") }
    public static var documentInput: String { localized("document_input") }
    public static var editProvider: String { localized("edit_provider") }
    public static var embeddings: String { localized("embeddings") }
    public static var endpoint: String { localized("endpoint") }
    public static var enterWholeNumberOrEmpty: String { localized("enter_whole_number_or_empty") }
    public static var error: String { localized("error") }
    public static var future: String { localized("future") }
    public static var imageGeneration: String { localized("image_generation") }
    public static var initializing: String { localized("initializing") }
    public static var jumpToLatest: String { localized("jump_to_latest") }
    public static var like: String { localized("like") }
    public static var limits: String { localized("limits") }
    public static var loading: String { localized("loading") }
    public static var loadingProviderSelection: String { localized("loading_provider_selection") }
    public static var usingConfiguredModel: String { localized("using_configured_model") }
    public static var usingCachedModels: String { localized("using_cached_models") }
    public static var modelDiscoveryFailed: String { localized("model_discovery_failed") }
    public static var major: String { localized("major") }
    public static var manageProviders: String { localized("manage_providers") }
    public static var maxRequestsPerMinute: String { localized("max_requests_per_minute") }
    public static var menu: String { localized("menu") }
    public static var messagePlaceholder: String { localized("message_placeholder") }
    public static var minor: String { localized("minor") }
    public static var model: String { localized("model") }
    public static var modelCapabilities: String { localized("model_capabilities") }
    public static var more: String { localized("more") }
    public static var newChat: String { localized("new_chat") }
    public static var newConversation: String { localized("new_conversation") }
    public static var noProviderAvailable: String { localized("no_provider_available") }
    public static var noModelsAvailable: String { localized("no_models_available") }
    public static var loadingModels: String { localized("loading_models") }
    public static var noProviderConnections: String { localized("no_provider_connections") }
    public static var noProviderConnectionsDescription: String { localized("no_provider_connections_description") }
    public static var noSearchResults: String { localized("no_search_results") }
    public static var noConfigurationValues: String { localized("no_configuration_values") }
    public static var omniaIsThinking: String { localized("omnia_is_thinking") }
    public static var omniaIsTyping: String { localized("omnia_is_typing") }
    public static var older: String { localized("older") }
    public static var openProviders: String { localized("open_providers") }
    public static var patch: String { localized("patch") }
    public static func providerSelectionCurrent(_ provider: String) -> String {
        String(format: localized("provider_selection_current"), provider)
    }
    public static var providers: String { localized("providers") }
    public static var providersStoredSecurely: String { localized("providers_stored_securely") }
    public static var previousSevenDays: String { localized("previous_seven_days") }
    public static var ready: String { localized("ready") }
    public static var reasoning: String { localized("reasoning") }
    public static var regenerate: String { localized("regenerate") }
    public static var rename: String { localized("rename") }
    public static var renameConversation: String { localized("rename_conversation") }
    public static var registered: String { localized("registered") }
    public static var remove: String { localized("remove") }
    public static var removeAttachments: String { localized("remove_attachments") }
    public static var removeProviderConnection: String { localized("remove_provider_connection") }
    public static var removeProviderConnectionConfirmation: String { localized("remove_provider_connection_confirmation") }
    public static var removed: String { localized("removed") }
    public static var requestSendFailed: String { localized("request_send_failed") }
    public static var requestInvalidEndpoint: String { localized("request_invalid_endpoint") }
    public static var requestNetworkUnavailable: String { localized("request_network_unavailable") }
    public static var requestRateLimited: String { localized("request_rate_limited") }
    public static var requestServerFailure: String { localized("request_server_failure") }
    public static var requestTimedOut: String { localized("request_timed_out") }
    public static var requestUnauthorized: String { localized("request_unauthorized") }
    public static var responseComplete: String { localized("response_complete") }
    public static var responseInterrupted: String { localized("response_interrupted") }
    public static var responseInterruptedRetry: String { localized("response_interrupted_retry") }
    public static var responseProcessingFailed: String { localized("response_processing_failed") }
    public static var retry: String { localized("retry") }
    public static var save: String { localized("save") }
    public static var saveProviderConnection: String { localized("save_provider_connection") }
    public static var searchConversations: String { localized("search_conversations") }
    public static var send: String { localized("send") }
    public static var settings: String { localized("settings") }
    public static var startNewConversation: String { localized("start_new_conversation") }
    public static var startNewConversationDescription: String { localized("start_new_conversation_description") }
    public static var stop: String { localized("stop") }
    public static var storageUnavailable: String { localized("storage_unavailable") }
    public static var streaming: String { localized("streaming") }
    public static var structuredOutput: String { localized("structured_output") }
    public static var supported: String { localized("supported") }
    public static var unsupported: String { localized("unsupported") }
    public static var unknownSupport: String { localized("unknown_support") }
    public static var textGeneration: String { localized("text_generation") }
    public static var thinking: String { localized("thinking") }
    public static var today: String { localized("today") }
    public static var toolCalling: String { localized("tool_calling") }
    public static var tryAgain: String { localized("try_again") }
    public static var unavailable: String { localized("unavailable") }
    public static var unexpectedError: String { localized("unexpected_error") }
    public static var untitledConversation: String { localized("untitled_conversation") }
    public static var validated: String { localized("validated") }
    public static var version: String { localized("version") }
    public static var versionPartsNonNegative: String { localized("version_parts_non_negative") }
    public static var vision: String { localized("vision") }
    public static var workspace: String { localized("workspace") }
    public static var yesterday: String { localized("yesterday") }
    public static func providerUnavailable(_ provider: String) -> String {
        String(format: localized("provider_unavailable"), provider)
    }
    public static func modelUnavailable(_ model: String) -> String {
        String(format: localized("model_unavailable"), model)
    }
    public static func removeAttachment(_ name: String) -> String {
        String(format: localized("remove_attachment"), name)
    }
    public static func attachmentError(_ error: AttachmentError) -> String {
        switch error {
        case .unsupportedType(let fileName):
            return String(format: localized("attachment_unsupported_type"), fileName)
        case .unreadable(let fileName):
            return String(format: localized("attachment_unreadable"), fileName)
        case .empty(let fileName):
            return String(format: localized("attachment_empty"), fileName)
        case .fileTooLarge(let fileName, let limit):
            return String(
                format: localized("attachment_file_too_large"),
                fileName,
                ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)
            )
        case .aggregateTooLarge(let limit):
            return String(
                format: localized("attachment_aggregate_too_large"),
                ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)
            )
        case .tooManyFiles(let limit):
            return String(format: localized("attachment_too_many"), limit)
        case .duplicate(let fileName):
            return String(format: localized("attachment_duplicate"), fileName)
        case .capabilityUnsupported(let kind):
            return String(
                format: localized("attachment_capability_unsupported"),
                attachmentKind(kind)
            )
        case .capabilityUnknown(let kind):
            return String(
                format: localized("attachment_capability_unknown"),
                attachmentKind(kind)
            )
        case .extractionFailed(let fileName):
            return String(format: localized("attachment_extraction_failed"), fileName)
        case .extractedTextTooLarge(let fileName, let limit):
            return String(
                format: localized("attachment_text_too_large"),
                fileName,
                limit
            )
        case .storageUnavailable:
            return localized("attachment_storage_unavailable")
        }
    }

    private static func attachmentKind(_ kind: AttachmentKind) -> String {
        switch kind {
        case .image: return localized("attachment_kind_image")
        case .pdf: return localized("attachment_kind_pdf")
        case .plainText: return localized("attachment_kind_text")
        }
    }
}
