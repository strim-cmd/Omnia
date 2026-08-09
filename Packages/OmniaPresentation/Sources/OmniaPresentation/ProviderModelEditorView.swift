#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI model-edit intent of the settings surface (DES-012 §3.4): the
/// user's update of the OpenAI-compatible model — the OmniRoute combo, or any
/// provider model name — of an existing provider connection, pre-filled with
/// the currently recorded model, translated into the model-update intent of the
/// settings surface. The view renders the model form and translates intent; it
/// owns no business logic (ARC-002). The interface is generic and never changes
/// per provider (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// Only the model is edited: the connection declaration — display name,
/// capabilities, limits, version — its endpoint, and its stored credential are
/// unchanged. The model is connection configuration the user owns (ARC-005) and
/// never enters the connection declaration or any Domain aggregate (DES-011
/// §3.10, ARC-004); it is validated at the service boundary, and an empty model
/// surfaces as the typed `ApplicationValidationError` the settings state
/// presents (DES-011 §3.6).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProviderModelEditorView: View {
    /// The declared display name of the provider connection, presented as the
    /// editor's context.
    public let displayName: String
    /// Translates the save intent with the updated model.
    public let onSave: (String) -> Void
    /// Translates the cancel intent.
    public let onCancel: () -> Void

    @State private var model: String

    /// Creates a provider model editor pre-filled with the connection's
    /// currently recorded model.
    public init(
        displayName: String,
        currentModel: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.onSave = onSave
        self.onCancel = onCancel
        self._model = State(initialValue: currentModel)
    }

    public var body: some View {
        Form {
            Section {
                TextField(Localized.model, text: $model)
                    #if os(iOS)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            } footer: {
                Text(Localized.updateModel(displayName))
            }
        }
        .navigationTitle(Localized.editModel)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Localized.cancel, action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(Localized.save, action: submit)
                    .disabled(!canSubmit)
                    .accessibilityLabel(Text(Localized.saveModel))
            }
        }
    }

    /// Submits the updated model, trimmed of surrounding whitespace. The
    /// service validates the model at its boundary; `canSubmit` guarantees an
    /// empty model never reaches the service.
    private func submit() {
        guard canSubmit else { return }
        onSave(trimmedModel)
    }

    /// The save is enabled when the model is not empty — the service rejects
    /// an empty model with the typed `ApplicationValidationError`.
    private var canSubmit: Bool {
        !trimmedModel.isEmpty
    }

    private var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#endif
