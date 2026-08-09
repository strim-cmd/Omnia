#if canImport(SwiftUI)

import SwiftUI

/// Localized strings for the presentation layer (UX audit A5).
///
/// Consolidates all user-visible strings into a localization catalog.
/// Follows UI.md §Localization and ARC-005.
public enum Localized {
    public static var addConnection: String { String(localized: "add_connection") }
    public static var apiKey: String { String(localized: "api_key") }
    public static var assistantIsResponding: String { String(localized: "assistant_is_responding") }
    public static var assistantMessage: String { String(localized: "assistant_message") }
    public static var audio: String { String(localized: "audio") }
    public static var automatic: String { String(localized: "automatic") }
    public static var cancel: String { String(localized: "cancel") }
    public static var capabilities: String { String(localized: "capabilities") }
    public static var configuration: String { String(localized: "configuration") }
    public static var configureProvider: String { String(localized: "configure_provider") }
    public static var connection: String { String(localized: "connection") }
    public static var conversation: String { String(localized: "conversation") }
    public static var delete: String { String(localized: "delete") }
    public static var deleteConversation: String { String(localized: "delete_conversation") }
    public static var deleteConversationConfirmation: String { String(localized: "delete_conversation_confirmation") }
    public static var disabled: String { String(localized: "disabled") }
    public static var displayName: String { String(localized: "display_name") }
    public static var editEndpoint: String { String(localized: "edit_endpoint") }
    public static var editModel: String { String(localized: "edit_model") }
    public static var embeddings: String { String(localized: "embeddings") }
    public static var endpoint: String { String(localized: "endpoint") }
    public static var enterWholeNumberOrEmpty: String { String(localized: "enter_whole_number_or_empty") }
    public static var imageGeneration: String { String(localized: "image_generation") }
    public static var interrupted: String { String(localized: "interrupted") }
    public static var jumpToLatest: String { String(localized: "jump_to_latest") }
    public static var limits: String { String(localized: "limits") }
    public static var loading: String { String(localized: "loading") }
    public static var loadingProviderSelection: String { String(localized: "loading_provider_selection") }
    public static var major: String { String(localized: "major") }
    public static var maxRequestsPerMinute: String { String(localized: "max_requests_per_minute") }
    public static var message: String { String(localized: "message") }
    public static var minor: String { String(localized: "minor") }
    public static var model: String { String(localized: "model") }
    public static var newConversation: String { String(localized: "new_conversation") }
    public static var noConversations: String { String(localized: "no_conversations") }
    public static var noConversationsDescription: String { String(localized: "no_conversations_description") }
    public static var noProviderConnections: String { String(localized: "no_provider_connections") }
    public static var noProviderConnectionsDescription: String { String(localized: "no_provider_connections_description") }
    public static var noConfigurationValues: String { String(localized: "no_configuration_values") }
    public static var openSettings: String { String(localized: "open_settings") }
    public static var patch: String { String(localized: "patch") }
    public static var preparing: String { String(localized: "preparing") }
    public static var providerConnections: String { String(localized: "provider_connections") }
    public static func providerSelectionCurrent(_ provider: String) -> String {
        String(format: String(localized: "provider_selection_current"), provider)
    }
    public static var ready: String { String(localized: "ready") }
    public static var reasoning: String { String(localized: "reasoning") }
    public static var registered: String { String(localized: "registered") }
    public static var remove: String { String(localized: "remove") }
    public static var removeProviderConfirmation: String { String(localized: "remove_provider_confirmation") }
    public static var responseComplete: String { String(localized: "response_complete") }
    public static var responseInterrupted: String { String(localized: "response_interrupted") }
    public static var retry: String { String(localized: "retry") }
    public static var retryInterruptedResponse: String { String(localized: "retry_interrupted_response") }
    public static var save: String { String(localized: "save") }
    public static var saveEndpoint: String { String(localized: "save_endpoint") }
    public static var saveModel: String { String(localized: "save_model") }
    public static var saveProviderConnection: String { String(localized: "save_provider_connection") }
    public static var send: String { String(localized: "send") }
    public static var settings: String { String(localized: "settings") }
    public static var stop: String { String(localized: "stop") }
    public static var streaming: String { String(localized: "streaming") }
    public static var structuredOutput: String { String(localized: "structured_output") }
    public static var textGeneration: String { String(localized: "text_generation") }
    public static var toolCalling: String { String(localized: "tool_calling") }
    public static var unavailable: String { String(localized: "unavailable") }
    public static var untitledConversation: String { String(localized: "untitled_conversation") }
    public static func updateEndpoint(_ provider: String) -> String {
        String(format: String(localized: "update_endpoint"), provider)
    }
    public static func updateModel(_ provider: String) -> String {
        String(format: String(localized: "update_model"), provider)
    }
    public static var userMessage: String { String(localized: "user_message") }
    public static var validated: String { String(localized: "validated") }
    public static var version: String { String(localized: "version") }
    public static var vision: String { String(localized: "vision") }
    public static func providerUnavailable(_ provider: String) -> String {
        String(format: String(localized: "provider_unavailable"), provider)
    }
    public static func providerStateCount(_ count: Int) -> String {
        String(format: String(localized: "provider_state_count"), count)
    }
    public static func providerStateCountRange(_ start: Int, _ end: Int) -> String {
        String(format: String(localized: "provider_state_count_range"), start, end)
    }
}

#endif