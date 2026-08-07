#if canImport(SwiftUI)

import OmniaApplication
import OmniaFoundation
import SwiftUI

/// The SwiftUI connection-form intent of the settings surface (DES-012 §3.4):
/// the user's declaration of a new provider connection — display name,
/// capabilities, limits, version, and the credential entered by the user —
/// translated into the frozen `ConfigureProviderRequest` and handed to
/// `SettingsSurface.configure`. The view renders the compose form and
/// translates intent; it owns no business logic (ARC-002). The interface is
/// generic and never changes per provider (`PRODUCT_PRINCIPLES` — Provider
/// Independence).
///
/// The credential boundary is honored: the entered secret lives only in the
/// secure text field and is passed into the frozen `ConfigureProviderRequest`,
/// whose storage by reference is the service's concern (DES-011 §3.4,
/// ARC-005); the field is cleared on submit, and the secret is never
/// persisted, logged, or rendered by the view (ARC-001, ARC-005).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `.ai/standards/UI.md`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProviderConnectionFormView: View {
    /// Translates the submit intent with the composed request.
    public let onConfigure: (ConfigureProviderRequest) -> Void
    /// Translates the cancel intent.
    public let onCancel: () -> Void

    @State private var displayName = ""
    @State private var selectedCapabilities: Set<Capability> = [.textGeneration, .conversation, .streaming]
    @State private var maxRequestsPerMinute = ""
    @State private var versionMajor = "1"
    @State private var versionMinor = "0"
    @State private var versionPatch = "0"
    @State private var credentialSecret = ""

    /// Creates a provider connection form over the given intent callbacks.
    public init(
        onConfigure: @escaping (ConfigureProviderRequest) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onConfigure = onConfigure
        self.onCancel = onCancel
    }

    public var body: some View {
        Form {
            Section("Connection") {
                TextField("Display Name", text: $displayName)
                SecureField("API Key", text: $credentialSecret)
            }
            Section("Capabilities") {
                ForEach(Self.allCapabilities, id: \.self) { capability in
                    Toggle(capabilityLabel(capability), isOn: binding(for: capability))
                }
            }
            Section("Limits") {
                TextField("Max Requests per Minute", text: $maxRequestsPerMinute)
            }
            Section("Version") {
                HStack {
                    TextField("Major", text: $versionMajor)
                    TextField("Minor", text: $versionMinor)
                    TextField("Patch", text: $versionPatch)
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

    /// Submits the declaration as a frozen `ConfigureProviderRequest` (DES-012
    /// §3.4): the display name trimmed, the declared capabilities, the stated
    /// limits and version, and the entered credential. The credential field is
    /// cleared on submit (ARC-005).
    private func submit() {
        guard canSubmit else { return }
        onConfigure(
            ConfigureProviderRequest(
                displayName: trimmedDisplayName,
                capabilities: ProviderCapabilities(capabilities: selectedCapabilities),
                limits: ProviderLimits(maxRequestsPerMinute: Int(maxRequestsPerMinute)),
                version: SemanticVersion(
                    major: Int(versionMajor) ?? 0,
                    minor: Int(versionMinor) ?? 0,
                    patch: Int(versionPatch) ?? 0
                ),
                credential: Credential(secret: credentialSecret)
            )
        )
        credentialSecret = ""
    }

    /// The submit is enabled when the declaration is complete — a display
    /// name, at least one capability, and a credential — so an incomplete
    /// declaration never reaches the service.
    private var canSubmit: Bool {
        !trimmedDisplayName.isEmpty && !selectedCapabilities.isEmpty && !credentialSecret.isEmpty
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
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
