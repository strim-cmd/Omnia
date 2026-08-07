#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the settings surface (DES-012 §3.4): the provider
/// connection rows — display name and lifecycle state — with the compose and
/// remove intents, and the typed configuration values the surface presents,
/// with the reset intent. The view renders state and translates intent; it
/// owns no business logic (ARC-002). Removing a connection is the user's
/// removal of their own content and its stored credential (ARC-005); the
/// credential is never rendered — only the configured state is presented
/// (ARC-001, ARC-005). The interface is generic and never changes per provider
/// (`PRODUCT_PRINCIPLES` — Provider Independence).
///
/// When the compose condition holds, the connection-form intent is presented.
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
    /// Translates the reset intent for the configuration key with the given
    /// name.
    public let onResetConfiguration: (ConfigurationKey<String>) -> Void

    /// Creates a settings view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        onCompose: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onConfigure: @escaping (ConfigureProviderRequest, String) -> Void,
        onRemove: @escaping (ProviderIdentity) -> Void,
        onResetConfiguration: @escaping (ConfigurationKey<String>) -> Void
    ) {
        self.state = state
        self.onCompose = onCompose
        self.onCancel = onCancel
        self.onConfigure = onConfigure
        self.onRemove = onRemove
        self.onResetConfiguration = onResetConfiguration
    }

    public var body: some View {
        Group {
            if state.isComposing {
                ProviderConnectionFormView(onConfigure: onConfigure, onCancel: onCancel)
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        Form {
            Section("Provider Connections") {
                if state.connections.isEmpty {
                    emptyConnectionsState
                } else {
                    ForEach(state.connections, id: \.identity) { item in
                        connectionRow(item)
                    }
                }
            }
            Section("Configuration") {
                if state.configuration.isEmpty {
                    Text("No configuration values.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.configuration, id: \.key.name) { item in
                        configurationRow(item)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCompose) {
                    Label("Add Connection", systemImage: "plus")
                }
                .accessibilityLabel(Text("Add Connection"))
            }
        }
        .safeAreaInset(edge: .top) {
            if let failure = state.failure {
                failureBanner(failure)
            }
        }
    }

    private func connectionRow(_ item: ProviderConnectionListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                Text(stateLabel(item.state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onRemove(item.identity)
            } label: {
                Label("Remove", systemImage: "trash")
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
        VStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Provider Connections")
                .font(.headline)
            Text("Add a connection to start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func failureBanner(_ failure: SettingsState.Failure) -> some View {
        Label("Something went wrong. Please try again.", systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .accessibilityLabel(Text("Error"))
    }

    /// The generic lifecycle state label of a provider connection row — the
    /// rendering of the Domain `ProviderState`, never provider-specific
    /// (ARC-004).
    private func stateLabel(_ state: ProviderState) -> String {
        switch state {
        case .registered: "Registered"
        case .validated: "Validated"
        case .initializing: "Preparing"
        case .ready: "Ready"
        case .unavailable: "Unavailable"
        case .disabled: "Disabled"
        case .removed: "Removed"
        }
    }
}

#endif
