#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the providers surface (DES-012 §3.4, new_design.md
/// §7): the provider-connection management destination of the shell — the
/// provider connection rows with the compose, provider-edit, and remove intents
/// — distinct from the application-settings destination, which remains in
/// `SettingsView`. The view renders state and translates intent; it owns no
/// business logic (ARC-002). Removing a connection is the user's removal of
/// their own content and its stored credential (ARC-005); the credential is
/// never rendered — only the configured state is presented (ARC-001, ARC-005).
/// The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// When the compose condition holds, the connection form is presented; when
/// the provider-edit condition holds, the same form is presented pre-filled
/// with the connection's current declaration, endpoint, and model — the unified
/// Edit Provider flow (DES-012 §3.4), replacing the separate endpoint and
/// model editors.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct ProvidersView: View {
    /// The ready-to-render settings state the providers surface presents.
    public let state: SettingsState
    /// Translates the compose intent — the connection-form is presented.
    public let onCompose: () -> Void
    /// Translates the cancel intent — the compose condition is cleared.
    public let onCancel: () -> Void
    /// Translates the configure intent — the connection-form is submitted with
    /// the composed request, the declared endpoint, the declared model, and the
    /// declared API family.
    public let onConfigure: (ConfigureProviderRequest, String, String, ProviderAPIKind) -> Void
    /// Translates the provider-edit intent — the connection form is presented
    /// pre-filled for the connection with the given identity.
    public let onEditProvider: (ProviderConnectionListItem) -> Void
    /// Translates the provider-update intent — the edit form is submitted for
    /// the connection with the given identity.
    public let onUpdateProvider: (ProviderIdentity, ProviderUpdateRequest, String, String, ProviderAPIKind) -> Void
    public let onTestConnection: (ProviderConnectionTestRequest) -> Void
    /// Translates the cancel-provider-edit intent — the edit form is dismissed.
    public let onCancelEdit: () -> Void
    /// Translates the remove intent for the connection with the given identity.
    public let onRemove: (ProviderIdentity) -> Void
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void

    /// The connection awaiting destructive confirmation before the remove intent
    /// is translated — nil until a destructive action is requested. A full swipe
    /// never removes: the confirm step is explicit and the system confirmation
    /// dialog is the accessibility path (UX audit U5).
    @State private var pendingRemoval: ProviderIdentity?

    /// Creates a providers view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        onCompose: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onConfigure: @escaping (ConfigureProviderRequest, String, String, ProviderAPIKind) -> Void,
        onEditProvider: @escaping (ProviderConnectionListItem) -> Void,
        onUpdateProvider: @escaping (ProviderIdentity, ProviderUpdateRequest, String, String, ProviderAPIKind) -> Void,
        onTestConnection: @escaping (ProviderConnectionTestRequest) -> Void,
        onCancelEdit: @escaping () -> Void,
        onRemove: @escaping (ProviderIdentity) -> Void,
        onOpenMenu: @escaping () -> Void
    ) {
        self.state = state
        self.onCompose = onCompose
        self.onCancel = onCancel
        self.onConfigure = onConfigure
        self.onEditProvider = onEditProvider
        self.onUpdateProvider = onUpdateProvider
        self.onTestConnection = onTestConnection
        self.onCancelEdit = onCancelEdit
        self.onRemove = onRemove
        self.onOpenMenu = onOpenMenu
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
                                ProviderConnectionFormView(
                                    onConfigure: onConfigure,
                                    onUpdate: { _, _, _, _ in },
                                    connectionTestCondition: state.connectionTestCondition,
                                    onTestConnection: onTestConnection,
                                    onCancel: onCancel
                                )
                            } else if let editing = state.editing {
                                ProviderConnectionFormView(
                                    editing: editing,
                                    onConfigure: { _, _, _, _ in },
                                    onUpdate: { request, endpoint, model, apiKind in
                                        onUpdateProvider(editing.identity, request, endpoint, model, apiKind)
                                    },
                                    connectionTestCondition: state.connectionTestCondition,
                                    onTestConnection: onTestConnection,
                                    onCancel: onCancelEdit
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
    /// add-connection button (new_design.md §7). The menu affordance opens the
    /// navigation drawer, owned by the shell; the add-connection button
    /// translates the compose intent of the providers content (CHAT.md). The
    /// add-connection button is hidden while a form is presented — compose or
    /// provider-edit — so the screen never offers a second form next to the
    /// one already shown.
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: onOpenMenu)
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(Localized.providers)
                .font(OmniaTheme.Typography.screenTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            if !state.isComposing && state.editing == nil {
                OmniaIconButton(systemImage: "plus", size: 36, action: onCompose)
                    .accessibilityLabel(Text(Localized.addConnection))
            }
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The main content of the screen: the providers sections and the security
    /// hint (new_design.md §7).
    private var mainContent: some View {
        VStack(spacing: OmniaTheme.Spacing.xl) {
            providersSection
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

    /// The trailing actions menu of a provider row: the provider-edit and
    /// remove intents (DES-012 §3.4, new_design.md §7). The single Edit
    /// Provider action presents the unified connection form pre-filled with
    /// the connection's current declaration, endpoint, and model.
    private func providerMenu(_ item: ProviderConnectionListItem) -> some View {
        Menu {
            Button {
                onEditProvider(item)
            } label: {
                Label(Localized.editProvider, systemImage: "pencil")
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
            case .capability(let error):
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

        static func message(for failure: CapabilityError) -> String {
            switch failure {
            case .providerUnavailable:
                return Localized.noProviderAvailable
            case .networkUnavailable:
                return Localized.requestNetworkUnavailable
            case .unauthorized:
                return Localized.requestUnauthorized
            case .invalidEndpoint:
                return Localized.requestInvalidEndpoint
            case .timedOut:
                return Localized.requestTimedOut
            case .rateLimited:
                return Localized.requestRateLimited
            case .serverFailure:
                return Localized.requestServerFailure
            case .modelUnavailable(let model):
                return Localized.modelUnavailable(model.name)
            case .invalidRequest:
                return Localized.requestSendFailed
            case .invalidResponse:
                return Localized.responseProcessingFailed
            case .streamingInterrupted:
                return Localized.responseInterruptedRetry
            }
        }
    }
}

#endif
