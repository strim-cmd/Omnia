#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the settings surface (DES-012 §3.4): the provider
/// connection rows — display name and lifecycle state — with the compose,
/// endpoint-edit, model-edit, and remove intents, the typed configuration
/// values the surface presents, with the reset intent, the Appearance section's
/// Dark Mode control, and the About item (new_design.md §7, §9, SCREENS/
/// SETTINGS.md). The view renders state and translates intent; it owns no
/// business logic (ARC-002). Removing a connection is the user's removal of
/// their own content and its stored credential (ARC-005); the credential is
/// never rendered — only the configured state is presented (ARC-001, ARC-005).
/// The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// In the current navigation model the settings surface also presents the
/// providers content (SCREENS/SETTINGS.md): the Providers and Settings items of
/// the navigation drawer route to this one destination. The Dark Mode toggle
/// drives the shell's presentation-only color-scheme state, shared with the
/// drawer's Dark Mode card and never persisted (ARC-002).
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
    /// Whether the shell forces the dark color scheme: presented as the
    /// Appearance section's Dark Mode toggle (new_design.md §9, COMPONENTS.md —
    /// ThemeToggle), shared with the navigation drawer.
    @Binding public var isDarkMode: Bool
    /// Translates the compose intent — the connection-form is presented.
    public let onCompose: () -> Void
    /// Translates the cancel intent — the compose condition is cleared.
    public let onCancel: () -> Void
    /// Translates the configure intent — the connection-form is submitted.
    public let onConfigure: (ConfigureProviderRequest, String, String) -> Void
    /// Translates the provider-edit intent — the connection is edited.
    public let onEditProvider: (ProviderConnectionListItem) -> Void
    /// Translates the model-edit intent — the model editor is presented for the
    /// connection with the given identity.
    public let onEditModel: (ProviderConnectionListItem) -> Void
    /// Translates the reset-configuration intent for the given configuration
    /// key — the user-owned setting is restored to its default.
    public let onResetConfiguration: (ConfigurationKey<String>) -> Void
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
    /// Translates the open-about intent — the shell routes to the about
    /// surface.
    public let onOpenAbout: () -> Void

    /// The connection awaiting destructive confirmation before the remove intent
    /// is translated — nil until a destructive action is requested. A full swipe
    /// never removes: the confirm step is explicit and the system confirmation
    /// dialog is the accessibility path (UX audit U5).
    @State private var pendingRemoval: ProviderIdentity?

    /// Creates a settings view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        isDarkMode: Binding<Bool>,
        onCompose: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onConfigure: @escaping (ConfigureProviderRequest, String, String) -> Void,
        onEditProvider: @escaping (ProviderConnectionListItem) -> Void,
        onEditModel: @escaping (ProviderConnectionListItem) -> Void,
        onResetConfiguration: @escaping (ConfigurationKey<String>) -> Void,
        onUpdateEndpoint: @escaping (ProviderIdentity, String) -> Void,
        onUpdateModel: @escaping (ProviderIdentity, String) -> Void,
        onCancelEndpointEdit: @escaping () -> Void,
        onCancelModelEdit: @escaping () -> Void,
        onRemove: @escaping (ProviderIdentity) -> Void,
        onOpenAbout: @escaping () -> Void
    ) {
        self.state = state
        self._isDarkMode = isDarkMode
        self.onCompose = onCompose
        self.onCancel = onCancel
        self.onConfigure = onConfigure
        self.onEditProvider = onEditProvider
        self.onEditModel = onEditModel
        self.onResetConfiguration = onResetConfiguration
        self.onUpdateEndpoint = onUpdateEndpoint
        self.onUpdateModel = onUpdateModel
        self.onCancelEndpointEdit = onCancelEndpointEdit
        self.onCancelModelEdit = onCancelModelEdit
        self.onRemove = onRemove
        self.onOpenAbout = onOpenAbout
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
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #else
        .toolbar(.hidden, for: .navigationBar)
        #endif
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

    /// The custom top bar of the screen: the menu button, the title, and the
    /// add-connection button (new_design.md §7). The menu affordance is inert
    /// exactly like the back affordance it replaces — navigation is owned by the
    /// shell (CHAT.md), and the reference presents a hamburger on the leading
    /// side of the providers screen.
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: {})
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(Localized.providers)
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

    /// The main content of the screen: the providers sections, the
    /// configuration values, the appearance item, the about item, and the
    /// security hint (new_design.md §7, §9, SCREENS/SETTINGS.md).
    private var mainContent: some View {
        VStack(spacing: OmniaTheme.Spacing.xl) {
            providersSection
            configurationSection
            appearanceSection
            aboutSection
            securityHint
        }
    }

    /// The providers sections: the prominent Active-Provider card and the
    /// All-Providers rows, or the empty state (new_design.md §7).
    @ViewBuilder
    private var providersSection: some View {
        if state.connections.isEmpty {
            emptyConnectionsState
        } else {
            activeProviderSection
            allProvidersSection
        }
    }

    /// The Active-Provider section: the heading and the prominent card of the
    /// ready provider (new_design.md §7). Omitted when no connection is ready;
    /// the All-Providers list then presents every connection.
    @ViewBuilder
    private var activeProviderSection: some View {
        if let active = activeProvider {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                SectionHeader(Localized.activeProvider)
                activeProviderCard(active)
            }
        }
    }

    /// The active provider: the connection that is ready to serve, presented as
    /// the prominent card of the providers section (new_design.md §7).
    private var activeProvider: ProviderConnectionListItem? {
        state.connections.first { $0.state == .ready }
    }

    /// The All-Providers section: the heading and the rows of the connections
    /// other than the active one — or every connection when none is active
    /// (new_design.md §7).
    @ViewBuilder
    private var allProvidersSection: some View {
        if !otherProviders.isEmpty {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                SectionHeader(Localized.allProviders)
                ForEach(otherProviders, id: \.identity) { item in
                    providerRow(item)
                }
            }
        }
    }

    /// The providers other than the active one, presented as the rows of the
    /// All-Providers list (new_design.md §7).
    private var otherProviders: [ProviderConnectionListItem] {
        state.connections.filter { $0.identity != activeProvider?.identity }
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

    /// The prominent card of the active provider: the accent provider glyph,
    /// the display name, the lifecycle label, the green Active pill, and the
    /// trailing overflow menu — the endpoint-edit, model-edit, and remove
    /// intents of the connection, so the ready provider is as manageable as
    /// every other connection (new_design.md §7, COMPONENTS.md — ProviderCard).
    private func activeProviderCard(_ item: ProviderConnectionListItem) -> some View {
        OmniaCard {
            HStack(spacing: OmniaTheme.Spacing.md) {
                providerIcon
                VStack(alignment: .leading, spacing: OmniaTheme.Spacing.xs) {
                    Text(item.displayName)
                        .font(OmniaTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(StatusIndicator(state: item.state).label)
                        .font(OmniaTheme.Typography.caption)
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                }
                Spacer(minLength: OmniaTheme.Spacing.sm)
                activePill
                providerMenu(item)
            }
        }
    }

    /// The accent provider glyph of the active provider (new_design.md §7).
    private var providerIcon: some View {
        Image(systemName: "network")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(OmniaTheme.Colors.accent)
            .frame(width: 40, height: 40)
            .background(
                OmniaTheme.Colors.accentSubtle,
                in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
            )
    }

    /// The green Active pill of the active provider: the success capsule that
    /// marks the ready connection (new_design.md §7).
    private var activePill: some View {
        Text(Localized.active)
            .font(OmniaTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(OmniaTheme.Colors.success)
            .padding(.horizontal, OmniaTheme.Spacing.md)
            .padding(.vertical, OmniaTheme.Spacing.xs)
            .background(OmniaTheme.Colors.success.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(OmniaTheme.Colors.success.opacity(0.3), lineWidth: 0.5)
            )
    }

    /// The row of a provider in the All-Providers list: the status dot, the
    /// display name, the lifecycle label, and the trailing actions menu
    /// (new_design.md §7).
    private func providerRow(_ item: ProviderConnectionListItem) -> some View {
        OmniaCard {
            HStack(spacing: OmniaTheme.Spacing.md) {
                StatusIndicator(state: item.state, showsLabel: false)
                VStack(alignment: .leading, spacing: OmniaTheme.Spacing.xs) {
                    Text(item.displayName)
                        .font(OmniaTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(StatusIndicator(state: item.state).label)
                        .font(OmniaTheme.Typography.caption)
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                }
                Spacer(minLength: OmniaTheme.Spacing.sm)
                providerMenu(item)
            }
        }
    }

    /// The trailing actions menu of a provider row: the endpoint-edit,
    /// model-edit, and remove intents (DES-012 §3.4, new_design.md §7).
    private func providerMenu(_ item: ProviderConnectionListItem) -> some View {
        Menu {
            Button {
                onEditProvider(item)
            } label: {
                Label(Localized.editEndpoint, systemImage: "pencil")
            }
            Button {
                onEditModel(item)
            } label: {
                Label(Localized.editModel, systemImage: "cpu")
            }
            Divider()
            Button(role: .destructive) {
                pendingRemoval = item.identity
            } label: {
                Label(Localized.remove, systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Localized.more))
    }

    /// The security hint of the screen: the provider connections are stored
    /// securely on this device (new_design.md §7).
    private var securityHint: some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(OmniaTheme.Typography.caption)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            Text(Localized.providersStoredSecurely)
                .font(OmniaTheme.Typography.caption)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OmniaTheme.Spacing.xs)
    }

    /// A configuration row: the key and the value (new_design.md §13).
    private func configurationRow(_ item: SettingsState.ConfigurationItem) -> some View {
        OmniaCard {
            HStack {
                Text(item.key.name)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Spacer()
                Text(item.value)
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            }
        }
    }

    /// The Appearance section: the heading and the Dark Mode row (new_design.md
    /// §9, SCREENS/SETTINGS.md).
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            SectionHeader(Localized.appearance)
            darkModeRow
        }
    }

    /// The Dark Mode row: the moon icon, the label, and the toggle control
    /// (new_design.md §9, COMPONENTS.md — ThemeToggle). The toggle drives the
    /// shell's color-scheme state, shared with the navigation drawer; it owns no
    /// state beyond the presented binding — persistence is the shell's concern
    /// (ARC-002).
    private var darkModeRow: some View {
        OmniaCard {
            HStack(spacing: OmniaTheme.Spacing.md) {
                Image(systemName: "moon")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
                    .frame(width: 22)
                Text(Localized.darkMode)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Spacer(minLength: OmniaTheme.Spacing.sm)
                Toggle("", isOn: $isDarkMode)
                    .labelsHidden()
                    .tint(OmniaTheme.Colors.accent)
                    .accessibilityLabel(Text(Localized.darkMode))
            }
        }
    }

    /// The About section: the heading and the About row (new_design.md §9,
    /// SCREENS/SETTINGS.md).
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            SectionHeader(Localized.about)
            aboutRow
        }
    }

    /// The About row: the info icon, the label, and the chevron accessory —
    /// routes to the about surface (new_design.md §9, SCREENS/SETTINGS.md).
    private var aboutRow: some View {
        Button(action: onOpenAbout) {
            OmniaCard {
                HStack(spacing: OmniaTheme.Spacing.md) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                        .frame(width: 22)
                    Text(Localized.about)
                        .font(OmniaTheme.Typography.body)
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    Spacer(minLength: OmniaTheme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(OmniaTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
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
            case .repository(let error):
                return FailureCopy.message(for: error)
            case .credentialStorage(let error):
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
                return Localized.storageUnavailable
            }
        }

        static func message(for failure: CredentialStorageError) -> String {
            switch failure {
            case .credentialNotFound:
                return Localized.credentialNotFound
            case .storageUnavailable:
                return Localized.credentialStorageUnavailable
            }
        }
    }
}

#endif
