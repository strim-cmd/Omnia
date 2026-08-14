import Foundation

/// The wire API family a provider connection targets (DES-011 §3.4, ARC-004).
///
/// The API kind is connection configuration the user owns: it selects which
/// Infrastructure adapter serves the connection. Like the endpoint and the
/// model, it is recorded as a typed configuration value at the provider-settings
/// level — keyed by the provider identity — and never enters the
/// `ProviderConnection` aggregate or the `ConfigureProviderRequest` (DES-011
/// §3.9, §3.10, ARC-004). A provider configured before the kind was recorded has
/// no value and resolves to `ProviderAPIKind.default` — the OpenAI-compatible
/// family — so existing connections keep serving unchanged.
///
/// `Codable` so the kind persists through the file-backed configuration
/// repository (DES-010 §3.3). Immutable and equal by content (ARC-003).
public enum ProviderAPIKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// An OpenAI-compatible chat-completions endpoint.
    case openAICompatible
    /// A Google Gemini (Generative Language API) endpoint.
    case gemini

    /// The API family a connection with no recorded kind uses — the family the
    /// connection form has always collected (DES-011 §3.9).
    public static let `default` = ProviderAPIKind.openAICompatible
}
