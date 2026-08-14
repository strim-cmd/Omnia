/// The exact provider/model pair selected for a conversation.
///
/// Provider identity is part of the value so two providers offering the same
/// model name can never be confused during request routing. The value is
/// persisted with the conversation and remains stable across navigation and
/// relaunch until the user explicitly replaces it.
public struct ProviderModelSelection: Codable, Equatable, Hashable, Sendable {
    public let provider: ProviderIdentity
    public let model: ModelReference

    public init(provider: ProviderIdentity, model: ModelReference) {
        self.provider = provider
        self.model = model
    }
}
