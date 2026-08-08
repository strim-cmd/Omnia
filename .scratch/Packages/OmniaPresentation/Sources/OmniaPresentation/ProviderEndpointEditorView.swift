#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI endpoint-edit intent of the settings surface (DES-012 §3.4):
/// the user's update of the OpenAI-compatible endpoint of an existing provider
/// connection — pre-filled with the currently recorded endpoint — translated
/// into the endpoint-update intent of the settings surface (UX audit U7). The
/// view renders the endpoint form and translates intent; it owns no business
/// logic (ARC-002). The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// Only the endpoint is edited: the connection declaration — display name,
/// capabilities, limits, version — and its stored credential are unchanged.
/// The endpoint is connection configuration the user owns (ARC-005) and never
/// enters the connection declaration or any Domain aggregate (DES-011 §3.9,
/// ARC-004); it is validated at the service boundary, and a malformed endpoint
/// surfaces as the typed `ApplicationValidationError` the settings state
/// presents (DES-011 §3.6).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `.ai/standards/UI.md`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProviderEndpointEditorView: View {
    /// The declared display name of the provider connection, presented as the
    /// editor's context.
    public let displayName: String
    /// Translates the save intent with the updated endpoint.
    public let onSave: (String) -> Void
    /// Translates the cancel intent.
    public let onCancel: () -> Void

    @State private var endpoint: String

    /// Creates a provider endpoint editor pre-filled with the connection's
    /// currently recorded endpoint.
    public init(
        displayName: String,
        currentEndpoint: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.onSave = onSave
        self.onCancel = onCancel
        self._endpoint = State(initialValue: currentEndpoint)
    }

    public var body: some View {
        Form {
            Section {
                TextField("Endpoint", text: $endpoint)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } footer: {
                Text("Update the endpoint \(displayName) connects to.")
            }
        }
        .navigationTitle("Edit Endpoint")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: submit)
                    .disabled(!canSubmit)
                    .accessibilityLabel(Text("Save Endpoint"))
            }
        }
    }

    /// Submits the updated endpoint, trimmed of surrounding whitespace. The
    /// service validates the endpoint at its boundary; `canSubmit` guarantees
    /// an empty endpoint never reaches the service.
    private func submit() {
        guard canSubmit else { return }
        onSave(trimmedEndpoint)
    }

    /// The save is enabled when the endpoint is not empty — the service
    /// rejects an empty endpoint with the typed `ApplicationValidationError`.
    private var canSubmit: Bool {
        !trimmedEndpoint.isEmpty
    }

    private var trimmedEndpoint: String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#endif
