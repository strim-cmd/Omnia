#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the settings surface (DES-012 §3.4): the provider
/// connection rows — display name and lifecycle state — with the compose,
/// endpoint-edit, and remove intents, and the typed configuration values the
/// surface presents, with the reset intent. The view renders state and
/// translates intent; it owns no business logic (ARC-002). Removing a
/// connection is the user's removal of their own content and its stored
/// credential (ARC-005); the credential is never rendered — only the configured
/// state is presented (ARC-001, ARC-005). The interface is generic and never
/// changes per provider (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// When the compose condition holds, the connection-form intent is presented;
/// when the endpoint-edit condition holds, the endpoint editor — the retry/edit
/// affordance of a non-ready provider connection, which offers a way to edit
/// the endpoint instead of only Remove (UX audit U7) — is presented.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `.ai/standards/UI.md`.
@available(iOS 15.0, macOS 12.0, *)
public struct SettingsView: View {
    /// The ready-to-render settings state.
    public let state: SettingsState
    /// Translates the compose intent — the connection-form is presented.
    public let onCompose: () -> Void
    /// Translates the cancel intent of the connection form.
    public let onCancel: () -> Void
    /// Translates the configure intent with the composed request and the
    /// declared endpoint.
    public let onConfigure: (ConfigureProviderRequest, String) -> Void
    /// Translates the remove intent for the connection with the given
    /// identity.
    public let onRemove: (ProviderIdentity) -> Void
    /// Translates the endpoint-edit intent for the connection with the given
    /// list item: the endpoint editor is presented (UX audit U7).
    public let onEditProvider: (ProviderConnectionListItem) -> Void
    /// Translates the endpoint-update intent for the connection with the given
    /// identity and the updated endpoint (UX audit U7).
    public let onUpdateEndpoint: (ProviderIdentity, String) -> Void
    /// Translates the cancel intent of the endpoint editor.
    public let onCancelEndpointEdit: () -> Void
    /// Translates the reset intent for the configuration key with the given
    /// name.
    public let onResetConfiguration: (ConfigurationKey<String>) -> Void

    /// The provider connection awaiting destructive confirmation before the
    /// remove intent is translated — nil until a destructive action is
    /// requested. A full swipe never removes: the confirm step is explicit,
    /// and the system confirmation dialog is the accessibility path (UX audit
    /// U5).
    @State private var pendingRemoval: ProviderIdentity?

    /// Creates a settings view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        onCompose: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onConfigure: @escaping (ConfigureProviderRequest, String) -> Void,
        onRemove: @escaping (ProviderIdentity) -> Void,
        onEditProvider: @escaping (ProviderConnectionListItem) -> Void,
        onUpdateEndpoint: @escaping (ProviderIdentity, String) -> Void,
        onCancelEndpointEdit: @escaping () -> Void,
        onResetConfiguration: @escaping (ConfigurationKey<String>) -> Void
    ) {
        self.state = state
        self.onCompose = onCompose
        self.onCancel = onCancel
        self.onConfigure = onConfigure
        self.onRemove = onRemove
        self.onEditProvider = onEditProvider
        self.onUpdateEndpoint = onUpdateEndpoint
        self.onCancelEndpointEdit = onCancelEndpointEdit
        self.onResetConfiguration = onResetConfiguration
    }

    public var body: some View {
        VStack(spacing: 0) {
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
                } else {
                    mainContent
                }
            }
        }
        .confirmationDialog(
            "Remove Provider Connection?",
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
            Button("Remove", role: .destructive) {
                onRemove(identity)
            }
        } message: { _ in
            Text("This will permanently remove the connection and its stored credential.")
        }
    }

    private var mainContent: some View {
        Form {
            Section {
                if state.connections.isEmpty {
                    emptyConnectionsState
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(state.connections, id: \.identity) { item in
                        connectionRow(item)
                    }
                }
            } header: {
                Text(Localized.providerConnections)
                    .font(.subheadline.bold())
            }

            Section {
                if state.configuration.isEmpty {
                    Text(Localized.noConfigurationValues)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.configuration, id: \.key.name) { item in
                        configurationRow(item)
                    }
                }
            } header: {
                Text(Localized.configuration)
                    .font(.subheadline.bold())
            }
        }
        .navigationTitle(Localized.settings)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCompose) {
                    Label(Localized.addConnection, systemImage: "plus")
                }
            }
        }
    }

    private func connectionRow(_ item: ProviderConnectionListItem) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.system(.body, design: .rounded, weight: .medium))
                Text(stateLabel(item.state))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEditProvider(item)
            } label: {
                Label(Localized.editEndpoint, systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingRemoval = item.identity
            } label: {
                Label(Localized.remove, systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingRemoval = item.identity
            } label: {
                Label(Localized.remove, systemImage: "trash")
            }
        }
    }

    private func configurationRow(_ item: SettingsState.ConfigurationItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.key.name)
                    .font(.body)
                Text(item.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onResetConfiguration(item.key)
            } label: {
                Label("Reset", systemImage: "arrow.uturn.backward")
            }
            .accessibilityLabel(Text("Reset \(item.key.name)"))
        }
    }

    private var emptyConnectionsState: some View {
        EmptyStateView(
            title: "No Provider Connections",
            description: "Add a connection to start.",
            systemImage: "externaldrive.badge.plus"
        )
    }

    private func failureBanner(_ failure: SettingsState.Failure) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
            .padding(.top, 4)
    }

    /// The generic lifecycle state label of a provider connection row — the
    /// rendering of the Domain `ProviderState` through the shared helper, never
    /// provider-specific (ARC-004).
    private func stateLabel(_ state: ProviderState) -> String {
        ProviderStateLabel.label(for: state)
    }
}

#endif
