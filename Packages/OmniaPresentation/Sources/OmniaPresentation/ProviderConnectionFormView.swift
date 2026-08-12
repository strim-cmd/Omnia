#if canImport(SwiftUI)

import OmniaApplication
import OmniaFoundation
import SwiftUI

/// The SwiftUI connection-form intent of the providers surface (DES-012 §3.4,
/// new_design.md §7): the unified provider form — compose and provider-edit —
/// collecting the display name, capabilities, limits, version, endpoint, and
/// the optional model of a provider connection, and, in compose, the credential
/// entered by the user. In compose the form translates the declaration into the
/// frozen `ConfigureProviderRequest`, the declared endpoint, and the declared
/// model, handed to `SettingsSurface.configure`; in provider-edit the same form
/// is presented pre-filled with the connection's current declaration, endpoint,
/// and model, and translates the edited declaration into the frozen
/// `ProviderUpdateRequest`, handed to `SettingsSurface.update` — one Edit
/// Provider action replaces the separate endpoint and model editors. The view
/// renders the form and translates intent; it owns no business logic (ARC-002).
/// The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// The credential boundary is honored: in compose, the entered secret lives
/// only in the secure text field and is passed into the frozen
/// `ConfigureProviderRequest`, whose storage by reference is the service's
/// concern (DES-011 §3.4, ARC-005); the field is cleared on submit, and the
/// secret is never persisted, logged, or rendered by the view (ARC-001,
/// ARC-005). In provider-edit the credential field is not presented — editing a
/// connection never requires re-entering the secret, and the stored credential
/// is kept by reference (ARC-001, ARC-005).
///
/// The endpoint and the optional model are collected with the connection
/// declaration and recorded by the settings surface through the service's
/// endpoint and model surfaces; they are connection configuration the user owns
/// (ARC-005) and never enter the `ConfigureProviderRequest`,
/// `ProviderUpdateRequest`, or any Domain aggregate (DES-011 §3.9, §3.10,
/// ARC-004). An empty model is allowed and records no model, so the provider
/// falls back to the app-edge default model.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProviderConnectionFormView: View {
    /// The provider-edit condition when the form is editing a connection, or
    /// `nil` when it is composing a new one.
    public let editing: SettingsState.Editing?
    /// Translates the compose-submit intent with the composed request, the
    /// declared endpoint, and the declared model.
    public let onConfigure: (ConfigureProviderRequest, String, String) -> Void
    /// Translates the edit-submit intent with the edited declaration, the
    /// declared endpoint, and the declared model.
    public let onUpdate: (ProviderUpdateRequest, String, String) -> Void
    /// Translates the cancel intent.
    public let onCancel: () -> Void

    @State private var displayName = ""
    @State private var selectedCapabilities: Set<Capability> = [.textGeneration, .conversation, .streaming]
    @State private var maxRequestsPerMinute = ""
    @State private var versionMajor = "1"
    @State private var versionMinor = "0"
    @State private var versionPatch = "0"
    @State private var endpoint = ""
    @State private var model = ""
    @State private var credentialSecret = ""

    /// Creates a provider connection form over the given intent callbacks,
    /// pre-filled with the connection's current declaration when editing.
    public init(
        editing: SettingsState.Editing? = nil,
        onConfigure: @escaping (ConfigureProviderRequest, String, String) -> Void,
        onUpdate: @escaping (ProviderUpdateRequest, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.editing = editing
        self.onConfigure = onConfigure
        self.onUpdate = onUpdate
        self.onCancel = onCancel
        _displayName = State(initialValue: editing?.displayName ?? "")
        _selectedCapabilities = State(
            initialValue: editing?.capabilities.capabilities
                ?? [.textGeneration, .conversation, .streaming]
        )
        _maxRequestsPerMinute = State(
            initialValue: editing?.limits.maxRequestsPerMinute.map(String.init) ?? ""
        )
        _versionMajor = State(initialValue: editing.map { String($0.version.major) } ?? "1")
        _versionMinor = State(initialValue: editing.map { String($0.version.minor) } ?? "0")
        _versionPatch = State(initialValue: editing.map { String($0.version.patch) } ?? "0")
        _endpoint = State(initialValue: editing?.currentEndpoint ?? "")
        _model = State(initialValue: editing?.currentModel ?? "")
        _credentialSecret = State(initialValue: "")
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: OmniaTheme.Spacing.lg) {
                connectionSection
                capabilitiesSection
                limitsSection
                versionSection
                actionButtons
            }
            .padding(OmniaTheme.Spacing.lg)
        }
        .background(OmniaTheme.Colors.background)
    }

    /// Whether the form edits a connection rather than composing a new one.
    private var isEditing: Bool {
        editing != nil
    }

    /// The connection section: the display name, endpoint, model, and — in
    /// compose — credential fields (new_design.md §14). In provider-edit the
    /// credential field is not presented: editing a connection never requires
    /// re-entering the secret (ARC-001, ARC-005).
    private var connectionSection: some View {
        OmniaCard {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                Text(Localized.connection)
                    .font(OmniaTheme.Typography.sectionTitle)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                TextField(Localized.displayName, text: $displayName)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    .tint(OmniaTheme.Colors.accent)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(OmniaTheme.Spacing.sm)
                    .background(OmniaTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                            .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                    )
                TextField(Localized.model, text: $model)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    .tint(OmniaTheme.Colors.accent)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(OmniaTheme.Spacing.sm)
                    .background(OmniaTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                            .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                    )
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                TextField(Localized.endpoint, text: $endpoint)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    .tint(OmniaTheme.Colors.accent)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(OmniaTheme.Spacing.sm)
                    .background(OmniaTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                            .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                    )
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                if !isEditing {
                    SecureField(Localized.apiKey, text: $credentialSecret)
                        .font(OmniaTheme.Typography.body)
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                        .tint(OmniaTheme.Colors.accent)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .padding(OmniaTheme.Spacing.sm)
                        .background(OmniaTheme.Colors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                        )
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
        }
    }

    /// The capabilities section: the declared capabilities of the connection
    /// (new_design.md §14).
    private var capabilitiesSection: some View {
        OmniaCard {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                Text(Localized.capabilities)
                    .font(OmniaTheme.Typography.sectionTitle)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                ForEach(Self.allCapabilities, id: \.self) { capability in
                    Toggle(capabilityLabel(capability), isOn: binding(for: capability))
                }
            }
        }
    }

    /// The limits section: the stated limits of the connection
    /// (new_design.md §14).
    private var limitsSection: some View {
        OmniaCard {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                Text(Localized.limits)
                    .font(OmniaTheme.Typography.sectionTitle)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                TextField(Localized.maxRequestsPerMinute, text: $maxRequestsPerMinute)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .autocorrectionDisabled()
                if showLimitError {
                    validationMessage(Localized.enterWholeNumberOrEmpty)
                }
            }
        }
    }

    /// The version section: the semantic version fields of the connection
    /// (new_design.md §14).
    private var versionSection: some View {
        OmniaCard {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                Text(Localized.version)
                    .font(OmniaTheme.Typography.sectionTitle)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                HStack {
                    TextField(Localized.major, text: $versionMajor)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .autocorrectionDisabled()
                    TextField(Localized.minor, text: $versionMinor)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .autocorrectionDisabled()
                    TextField(Localized.patch, text: $versionPatch)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .autocorrectionDisabled()
                }
                if showVersionError {
                    validationMessage(Localized.versionPartsNonNegative)
                }
            }
        }
    }

    /// The action buttons of the form: the cancel and save intents
    /// (new_design.md §14).
    private var actionButtons: some View {
        HStack(spacing: OmniaTheme.Spacing.md) {
            OmniaButton(
                title: Localized.cancel,
                systemImage: "xmark",
                style: .secondary,
                action: onCancel
            )
            OmniaButton(
                title: Localized.saveProviderConnection,
                systemImage: "checkmark",
                style: .primary,
                action: submit
            )
            .disabled(!canSubmit)
        }
    }

    /// Submits the form (DES-012 §3.4): in compose, as a frozen
    /// `ConfigureProviderRequest`, the declared endpoint, and the declared
    /// model — the display name trimmed, the declared capabilities, the stated
    /// limits and version, the endpoint, the optional model, and the entered
    /// credential (the field cleared on submit, ARC-005); in provider-edit, as
    /// a frozen `ProviderUpdateRequest` — the same declaration without a
    /// credential, since editing never re-enters the secret — with the declared
    /// endpoint and model. An empty model is allowed — it records no model, so
    /// the provider falls back to the app-edge default. `canSubmit` guarantees
    /// the numeric fields are valid, so the submitted values never contain a
    /// silently coerced value.
    private func submit() {
        guard canSubmit else { return }
        let declaration = {
            ProviderCapabilities(capabilities: selectedCapabilities)
        }
        let limits = ProviderLimits(maxRequestsPerMinute: parsedLimit)
        let version = SemanticVersion(
            major: parsedVersionMajor ?? 0,
            minor: parsedVersionMinor ?? 0,
            patch: parsedVersionPatch ?? 0
        )
        if isEditing {
            self.onUpdate(
                ProviderUpdateRequest(
                    displayName: trimmedDisplayName,
                    capabilities: declaration(),
                    limits: limits,
                    version: version
                ),
                trimmedEndpoint,
                trimmedModel
            )
        } else {
            self.onConfigure(
                ConfigureProviderRequest(
                    displayName: trimmedDisplayName,
                    capabilities: declaration(),
                    limits: limits,
                    version: version,
                    credential: Credential(secret: credentialSecret)
                ),
                trimmedEndpoint,
                trimmedModel
            )
        }
        credentialSecret = ""
    }

    /// The submit is enabled when the declaration is complete — a display
    /// name, at least one capability, an endpoint, and, in compose, a
    /// credential (provider-edit keeps the stored credential by reference) —
    /// and the numeric fields are valid, so an incomplete or invalid
    /// declaration never reaches the service.
    private var canSubmit: Bool {
        !trimmedDisplayName.isEmpty && !selectedCapabilities.isEmpty
            && !trimmedEndpoint.isEmpty && (isEditing || !credentialSecret.isEmpty)
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
            .foregroundStyle(OmniaTheme.Colors.error)
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEndpoint: String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedModel: String {
        self.model.trimmingCharacters(in: .whitespacesAndNewlines)
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
        case .textGeneration: Localized.textGeneration
        case .conversation: Localized.conversation
        case .streaming: Localized.streaming
        case .vision: Localized.vision
        case .imageGeneration: Localized.imageGeneration
        case .embeddings: Localized.embeddings
        case .toolCalling: Localized.toolCalling
        case .structuredOutput: Localized.structuredOutput
        case .audio: Localized.audio
        case .reasoning: Localized.reasoning
        }
    }

    /// The frozen Domain capability set of DES-009 §3.1, presented generically.
    private static let allCapabilities: [Capability] = [
        .textGeneration, .conversation, .streaming, .vision, .imageGeneration,
        .embeddings, .toolCalling, .structuredOutput, .audio, .reasoning,
    ]
}

#endif
