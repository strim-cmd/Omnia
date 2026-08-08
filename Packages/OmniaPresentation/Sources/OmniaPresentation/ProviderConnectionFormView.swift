#if canImport(SwiftUI)

import OmniaApplication
import OmniaFoundation
import SwiftUI

/// The SwiftUI connection-form intent of the settings surface (DES-012 §3.4):
/// the user's declaration of a new provider connection — display name,
/// capabilities, limits, version, the endpoint, and the credential entered by
/// the user — translated into the frozen `ConfigureProviderRequest` and the
/// declared endpoint, and handed to `SettingsSurface.configure`. The view
/// renders the compose form and translates intent; it owns no business logic
/// (ARC-002). The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// The credential boundary is honored: the entered secret lives only in the
/// secure text field and is passed into the frozen `ConfigureProviderRequest`,
/// whose storage by reference is the service's concern (DES-011 §3.4,
/// ARC-005); the field is cleared on submit, and the secret is never
/// persisted, logged, or rendered by the view (ARC-001, ARC-005).
///
/// The endpoint is collected with the connection declaration and recorded by
/// the settings surface through the service's endpoint surface; it is
/// connection configuration the user owns (ARC-005) and never enters the
/// `ConfigureProviderRequest` or any Domain aggregate (DES-011 §3.9, ARC-004).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `.ai/standards/UI.md`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProviderConnectionFormView: View {
    /// Translates the submit intent with the composed request and the declared
    /// endpoint.
    public let onConfigure: (ConfigureProviderRequest, String) -> Void
    /// Translates the cancel intent.
    public let onCancel: () -> Void

    @State private var displayName = ""
    @State private var selectedCapabilities: Set<Capability> = [.textGeneration, .conversation, .streaming]
    @State private var maxRequestsPerMinute = ""
    @State private var versionMajor = "1"
    @State private var versionMinor = "0"
    @State private var versionPatch = "0"
    @State private var endpoint = ""
    @State private var credentialSecret = ""

    /// Creates a provider connection form over the given intent callbacks.
    public init(
        onConfigure: @escaping (ConfigureProviderRequest, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onConfigure = onConfigure
        self.onCancel = onCancel
    }

    public var body: some View {
        Form {
            Section("Connection") {
                TextField("Display Name", text: $displayName)
                TextField("Endpoint", text: $endpoint)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("API Key", text: $credentialSecret)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section("Capabilities") {
                ForEach(Self.allCapabilities, id: \.self) { capability in
                    Toggle(capabilityLabel(capability), isOn: binding(for: capability))
                }
            }
            Section("Limits") {
                TextField("Max Requests per Minute", text: $maxRequestsPerMinute)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                if showLimitError {
                    validationMessage("Enter a whole number, or leave empty for no limit.")
                }
            }
            Section("Version") {
                HStack {
                    TextField("Major", text: $versionMajor)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                    TextField("Minor", text: $versionMinor)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                    TextField("Patch", text: $versionPatch)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                }
                if showVersionError {
                    validationMessage("Each version part must be a non-negative whole number.")
                }
            }
        }
        .navigationTitle("Configure Provider")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: submit)
                    .disabled(!canSubmit)
                    .accessibilityLabel(Text("Save Provider Connection"))
            }
        }
    }

    /// Submits the declaration as a frozen `ConfigureProviderRequest` and the
    /// declared endpoint (DES-012 §3.4): the display name trimmed, the declared
    /// capabilities, the stated limits and version, the endpoint, and the
    /// entered credential. The credential field is cleared on submit (ARC-005).
    /// `canSubmit` guarantees the numeric fields are valid, so the saved
    /// request never contains a silently coerced value.
    private func submit() {
        guard canSubmit else { return }
        onConfigure(
            ConfigureProviderRequest(
                displayName: trimmedDisplayName,
                capabilities: ProviderCapabilities(capabilities: selectedCapabilities),
                limits: ProviderLimits(maxRequestsPerMinute: parsedLimit),
                version: SemanticVersion(
                    major: parsedVersionMajor ?? 0,
                    minor: parsedVersionMinor ?? 0,
                    patch: parsedVersionPatch ?? 0
                ),
                credential: Credential(secret: credentialSecret)
            ),
            trimmedEndpoint
        )
        credentialSecret = ""
    }

    /// The submit is enabled when the declaration is complete — a display
    /// name, at least one capability, an endpoint, and a credential — and the
    /// numeric fields are valid, so an incomplete or invalid declaration never
    /// reaches the service.
    private var canSubmit: Bool {
        !trimmedDisplayName.isEmpty && !selectedCapabilities.isEmpty
            && !trimmedEndpoint.isEmpty && !credentialSecret.isEmpty
            && limitIsValid && versionIsValid
    }

    /// The stated limit as a non-negative integer: `nil` when the field is
    /// empty (no limit stated, per the frozen `ProviderLimits`), and never a
    /// silently coerced value for non-numeric text.
    private var parsedLimit: Int? {
        guard !maxRequestsPerMinute.isEmpty else { return nil }
        guard let value = Int(maxRequestsPerMinute), value >= 0 else { return nil }
        return value
    }

    private var limitIsValid: Bool {
        maxRequestsPerMinute.isEmpty || parsedLimit != nil
    }

    private var showLimitError: Bool {
        !limitIsValid
    }

    /// Each version part parsed as a non-negative integer; the parts are
    /// required (the frozen `SemanticVersion` has no empty form), so empty or
    /// non-numeric text is never coerced.
    private var parsedVersionMajor: Int? {
        guard let value = Int(versionMajor), value >= 0 else { return nil }
        return value
    }

    private var parsedVersionMinor: Int? {
        guard let value = Int(versionMinor), value >= 0 else { return nil }
        return value
    }

    private var parsedVersionPatch: Int? {
        guard let value = Int(versionPatch), value >= 0 else { return nil }
        return value
    }

    private var versionIsValid: Bool {
        parsedVersionMajor != nil && parsedVersionMinor != nil && parsedVersionPatch != nil
    }

    private var showVersionError: Bool {
        !versionIsValid
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEndpoint: String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func binding(for capability: Capability) -> Binding<Bool> {
        Binding(
            get: { selectedCapabilities.contains(capability) },
            set: { isSelected in
                if isSelected {
                    selectedCapabilities.insert(capability)
                } else {
                    selectedCapabilities.remove(capability)
                }
            }
        )
    }

    private func capabilityLabel(_ capability: Capability) -> String {
        switch capability {
        case .textGeneration: "Text Generation"
        case .conversation: "Conversation"
        case .streaming: "Streaming"
        case .vision: "Vision"
        case .imageGeneration: "Image Generation"
        case .embeddings: "Embeddings"
        case .toolCalling: "Tool Calling"
        case .structuredOutput: "Structured Output"
        case .audio: "Audio"
        case .reasoning: "Reasoning"
        }
    }

    /// The frozen Domain capability set of DES-009 §3.1, presented generically.
    private static let allCapabilities: [Capability] = [
        .textGeneration, .conversation, .streaming, .vision, .imageGeneration,
        .embeddings, .toolCalling, .structuredOutput, .audio, .reasoning,
    ]
}

#endif
