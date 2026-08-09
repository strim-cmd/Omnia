#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the settings surface (DES-012 §3.4): the provider
/// connection rows — display name and lifecycle state — with the compose,
/// endpoint-edit, model-edit, and remove intents, and the typed configuration
/// values the surface presents, with the reset intent. The view renders state
/// and translates intent; it owns no business logic (ARC-002). Removing a
/// connection is the user's removal of their own content and its stored
/// credential (ARC-005); the credential is never rendered — only the configured
/// state is presented (ARC-001, ARC-005). The interface is generic and never
/// changes per provider (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// When the compose condition holds, the connection-form intent is presented;
/// when the endpoint-edit condition holds, the endpoint editor — the retry/edit
/// affordance of a non-ready provider connection, which offers a way to edit
/// the endpoint instead of only Remove (UX audit U7) — is presented; when the
/// model-edit condition holds, the model editor — the affordance to edit the
/// connection's OpenAI-compatible model, mirroring the endpoint editor — is
/// presented.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct SettingsView: View {
    /// The ready-to-render settings state.
    public let state: SettingsState
    /// Translates the compose intent — the connection-form is presented.
    public let onCompose: () -> Void
    /// Translates the cancel intent — the compose condition is cleared.
    public let onCancel: () -> Void
    /// Translates the configure intent — the connection-form is submitted.
    public let onConfigure: (ProviderConnectionForm) -> Void
    /// Translates the endpoint-edit intent — the endpoint editor is presented
    /// for the connection with the given identity.
    public let onEditEndpoint: (ProviderIdentity) -> Void
    /// Translates the model-edit intent — the model editor is presented for the
    /// connection with the given identity.
    public let onEditModel: (ProviderIdentity) -> Void
    /// Translates the update-endpoint intent — the endpoint editor is submitted
    /// for the connection with the given identity.
    public let onUpdateEndpoint: (ProviderIdentity, String) -> Void
    /// Translates the update-model intent — the model editor is submitted for the
    /// connection with the given identity.
    public let onUpdateModel: (ProviderIdentity, String) -> Void
    /// Translates the cancel-endpoint-edit intent — the endpoint editor is
    /// dismissed.
    public let onCancelEndpointEdit: () -> Void
    /// Translates the cancel-model-edit intent — the model editor is dismissed.
    public let onCancelModelEdit: () -> Void
    /// Translates the remove intent for the connection with the given identity.
    public let onRemove: (ProviderIdentity) -> Void

    /// The connection awaiting destructive confirmation before the remove intent
    /// is translated — nil until a destructive action is requested. A full swipe
    /// never removes: the confirm step is explicit and the system confirmation
    /// dialog is the accessibility path (UX audit U5).
    @State private var pendingRemoval: ProviderIdentity?

    /// Creates a settings view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        onCompose: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onConfigure: @escaping (ProviderConnectionForm) -> Void,
        onEditEndpoint: @escaping (ProviderIdentity) -> Void,
        onEditModel: @escaping (ProviderIdentity) -> Void,
        onUpdateEndpoint: @escaping (ProviderIdentity, String) -> Void,
        onUpdateModel: @escaping (ProviderIdentity, String) -> Void,
        onCancelEndpointEdit: @escaping () -> Void,
        onCancelModelEdit: @escaping () -> Void,
        onRemove: @escaping (ProviderIdentity) -> Void
    ) {
        self.state = state
        self.onCompose = onCompose
        self.onCancel = onCancel
        self.onConfigure = onConfigure
        self.onEditEndpoint = onEditEndpoint
        self.onEditModel = onEditModel
        self.onUpdateEndpoint = onUpdateEndpoint
        self.onUpdateModel = onUpdateModel
        self.onCancelEndpointEdit = onCancelEndpointEdit
        self.onCancelModelEdit = onCancelModelEdit
        self.onRemove = onRemove
    }

    public var body: some View {
        ZStack(alignment: .top) {
            OmniaBackground()

            VStack(spacing: 0) {
                customTopBar
                ScrollView {
                    VStack(spacing: OmniaTheme.Spacing.lg) {
                        if let failure = state.failure {
                            failureBanner(failure)
                        }
                        Group {
                            if state.isComposing {
                                ProviderConnectionFormView(onConfigure: onConfigure, onCancel: onCancel)
                            } else if let editing = state.editing {
                                ProviderEndpointEditorView(
                                    displayName: editing.displayName,
                                    currentEndpoint: editing.currentEndpoint,
                                    onSave: { onUpdateEndpoint(editing.identity, $0) },
                                    onCancel: onCancelEndpointEdit
                                )
                            } else if let modelEditing = state.editingModel {
                                ProviderModelEditorView(
                                    displayName: modelEditing.displayName,
                                    currentModel: modelEditing.currentModel,
                                    onSave: { onUpdateModel(modelEditing.identity, $0) },
                                    onCancel: onCancelModelEdit
                                )
                            } else {
                                mainContent
                            }
                        }
                        .padding(OmniaTheme.Spacing.lg)
                    }
                }
            }
        }
        .confirmationDialog(
            Localized.removeProviderConnection,
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { presented in
                    if !presented {
                        pendingRemoval = nil
                    }
                }
            ),
            presenting: pendingRemoval
        ) { identity in
            Button(Localized.remove, role: .destructive) {
                onRemove(identity)
            }
        } message: { _ in
            Text(Localized.removeProviderConnectionConfirmation)
        }
    }

    /// The custom top bar of the screen: the back button, the title, and the
    /// add-connection button (new_design.md §13).
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "chevron.left", size: 36, action: {})
                .accessibilityLabel(Text(Localized.back))
            Spacer()
            Text(Localized.settings)
                .font(OmniaTheme.Typography.screenTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            OmniaIconButton(systemImage: "plus", size: 36, action: onCompose)
                .accessibilityLabel(Text(Localized.addConnection))
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The main content of the screen: the provider connections and
    /// configuration sections (new_design.md §13).
    private var mainContent: some View {
        VStack(spacing: OmniaTheme.Spacing.xl) {
            providerConnectionsSection
            configurationSection
        }
    }

    /// The provider connections section: the cards of the configured
    /// connections, or the empty state (new_design.md §13).
    private var providerConnectionsSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            Text(Localized.providerConnections)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
            if state.connections.isEmpty {
                emptyConnectionsState
            } else {
                ForEach(state.connections, id: \.identity) { item in
                    connectionCard(item)
                }
            }
        }
    }

    /// The configuration section: the key-value rows of the configuration
    /// values, or the empty state (new_design.md §13).
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            Text(Localized.configuration)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
            if state.configuration.isEmpty {
                Text(Localized.noConfigurationValues)
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            } else {
                ForEach(state.configuration, id: \.key.name) { item in
                    configurationRow(item)
                }
            }
        }
    }

    /// The empty connections state: no provider connection is configured, so
    /// the conversation cannot be served; the card states it plainly and invites
    /// adding a connection (new_design.md §13).
    private var emptyConnectionsState: some View {
        OmniaCard {
            VStack(spacing: OmniaTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(OmniaTheme.Colors.warning)
                Text(Localized.noProviderConnections)
                    .font(OmniaTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Text(Localized.noProviderConnectionsDescription)
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
                OmniaButton(
                    title: Localized.addConnection,
                    systemImage: "plus",
                    style: .primary,
                    action: onCompose
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// A provider connection card: the display name, the lifecycle state, and
    /// the action buttons (new_design.md §13).
    private func connectionCard(_ item: ProviderConnectionListItem) -> some View {
        OmniaCard {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                HStack {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OmniaTheme.Colors.accent)
                    }
                    Text(item.displayName)
                        .font(OmniaTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    Spacer()
                    statusDot(item.state)
                }
                if let endpoint = item.endpoint {
                    Text(endpoint)
                        .font(OmniaTheme.Typography.secondary)
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                if let model = item.model {
                    Text(model)
                        .font(OmniaTheme.Typography.secondary)
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: OmniaTheme.Spacing.sm) {
                    OmniaButton(
                        title: Localized.editEndpoint,
                        systemImage: "pencil",
                        style: .secondary,
                        action: { onEditEndpoint(item.identity) }
                    )
                    OmniaButton(
                        title: Localized.editModel,
                        systemImage: "cpu",
                        style: .secondary,
                        action: { onEditModel(item.identity) }
                    )
                    Spacer()
                    OmniaIconButton(
                        systemImage: "trash",
                        tint: OmniaTheme.Colors.textSecondary,
                        size: 28,
                        action: { pendingRemoval = item.identity }
                    )
                    .accessibilityLabel(Text(Localized.remove))
                }
            }
        }
    }

    /// The status dot of a provider connection: green when ready, amber when
    /// not ready (new_design.md §13).
    private func statusDot(_ state: ProviderConnectionListItem.State) -> some View {
        Circle()
            .fill(state == .ready ? OmniaTheme.Colors.success : OmniaTheme.Colors.warning)
            .frame(width: 8, height: 8)
    }

    /// A configuration row: the key and the value (new_design.md §13).
    private func configurationRow(_ item: ConfigurationItem) -> some View {
        OmniaCard {
            HStack {
                Text(item.key.displayName)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Spacer()
                Text(item.value)
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            }
        }
    }

    /// The failure banner of the screen: the error condition the screen
    /// presents (DES-012 §3.2).
    private func failureBanner(_ failure: SettingsState.Failure) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
    }

    /// User-facing copy for the typed failures the presentation views present —
    /// view-layer text derived from the typed error, never raw error detail
    /// (ARC-005). The failure is presented as it is, never silent (ARC-001): the
    /// banner text and its accessibility label both carry the message (UX audit
    /// A2/S2).
    enum FailureCopy {

        static func message(for failure: SettingsState.Failure) -> String {
            switch failure {
            case .application(let error):
                return FailureCopy.message(for: error)
            case .domain(let error):
                return FailureCopy.message(for: error)
            }
        }

        static func message(for failure: ApplicationValidationError) -> String {
            switch failure {
            case .invalid(let reason):
                return reason
            }
        }

        static func message(for failure: RepositoryError) -> String {
            switch failure {
            case .storageUnavailable:
                return "Storage is temporarily unavailable. Please try again."
            }
        }

        static func message(for failure: CredentialStorageError) -> String {
            switch failure {
            case .credentialNotFound:
                return "The stored credential could not be found. Check your connection settings."
            case .storageUnavailable:
                return "Secure credential storage is unavailable. Please try again."
            }
        }
    }
}

#endif
