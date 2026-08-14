#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the settings surface (DES-012 §3.4, new_design.md
/// §9, SCREENS/SETTINGS.md): the application-settings destination of the shell —
/// the typed configuration values the surface presents, the Appearance
/// section's Dark Mode control, and the About item — distinct from the
/// provider-management destination, which `ProvidersView` renders. The view
/// renders state and translates intent; it owns no business logic (ARC-002).
///
/// The Dark Mode toggle drives the shell's color scheme through the shared
/// binding with the drawer's Dark Mode card, and the choice is persisted at the
/// user-owned workspace level and restored on launch (DES-011 §3.5, ARC-005).
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
    /// Translates the open-about intent — the shell routes to the about
    /// surface.
    public let onOpenAbout: () -> Void
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void
    /// Opens the single provider/credential management destination.
    public let onOpenProviders: () -> Void
    /// Runs the confirmed Clear Data operation.
    public let onClearData: () -> Void
    /// Persists the coherent global provider/model default.
    public let onSetDefaultModel: (ProviderModelSelection) -> Void
    /// Persists an explicit model-scoped capability fact.
    public let onSetModelCapability: (
        ProviderModelSelection,
        Capability,
        ModelCapabilitySupport
    ) -> Void
    @State private var isClearDataConfirmationPresented = false

    /// Creates a settings view over the given state and intent callbacks.
    public init(
        state: SettingsState,
        isDarkMode: Binding<Bool>,
        onOpenAbout: @escaping () -> Void,
        onOpenMenu: @escaping () -> Void,
        onOpenProviders: @escaping () -> Void = {},
        onClearData: @escaping () -> Void = {},
        onSetDefaultModel: @escaping (ProviderModelSelection) -> Void = { _ in },
        onSetModelCapability: @escaping (
            ProviderModelSelection,
            Capability,
            ModelCapabilitySupport
        ) -> Void = { _, _, _ in }
    ) {
        self.state = state
        self._isDarkMode = isDarkMode
        self.onOpenAbout = onOpenAbout
        self.onOpenMenu = onOpenMenu
        self.onOpenProviders = onOpenProviders
        self.onClearData = onClearData
        self.onSetDefaultModel = onSetDefaultModel
        self.onSetModelCapability = onSetModelCapability
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
                        mainContent
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
            Localized.clearData,
            isPresented: $isClearDataConfirmationPresented
        ) {
            Button(Localized.clearData, role: .destructive, action: onClearData)
        } message: {
            Text(Localized.clearDataConfirmation)
        }
    }

    /// The custom top bar of the screen: the menu button, the title, and the
    /// trailing spacer that keeps the title centered (new_design.md §9). The
    /// menu affordance opens the navigation drawer, owned by the shell
    /// (CHAT.md).
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: onOpenMenu)
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(Localized.settings)
                .font(OmniaTheme.Typography.screenTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The main content of the screen: the configuration values, the appearance
    /// item, and the about item (new_design.md §9, SCREENS/SETTINGS.md).
    private var mainContent: some View {
        VStack(spacing: OmniaTheme.Spacing.xl) {
            configurationSection
            providerManagementSection
            defaultModelSection
            modelCapabilitiesSection
            appearanceSection
            dataSection
            aboutSection
        }
    }

    private var providerManagementSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            SectionHeader(Localized.providers)
            Button(action: onOpenProviders) {
                OmniaCard {
                    HStack(spacing: OmniaTheme.Spacing.md) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .foregroundStyle(OmniaTheme.Colors.textSecondary)
                        Text(Localized.manageProviders)
                            .foregroundStyle(OmniaTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(OmniaTheme.Colors.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            SectionHeader(Localized.data)
            OmniaCard {
                VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                    Text(Localized.clearDataScope)
                        .font(OmniaTheme.Typography.secondary)
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                    OmniaButton(
                        title: Localized.clearData,
                        systemImage: "trash",
                        style: .destructive
                    ) {
                        isClearDataConfirmationPresented = true
                    }
                }
            }
        }
    }

    /// A single coherent default pair. Changing provider necessarily chooses a
    /// model from that provider's own catalog; names never cross provider scope.
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
            SectionHeader(Localized.defaultModel)
            OmniaCard {
                VStack(alignment: .leading, spacing: OmniaTheme.Spacing.sm) {
                    Menu {
                        ForEach(state.connections, id: \.identity) { provider in
                            Menu(provider.displayName) {
                                let catalog = state.modelCatalogs.first {
                                    $0.provider == provider.identity
                                }
                                if let catalog, !catalog.models.isEmpty {
                                    ForEach(catalog.models, id: \.selection) { descriptor in
                                        Button {
                                            onSetDefaultModel(descriptor.selection)
                                        } label: {
                                            HStack {
                                                Text(descriptor.selection.model.name)
                                                if state.defaultModelSelection == descriptor.selection {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                        .disabled(provider.state != .ready)
                                    }
                                } else {
                                    Text(Localized.noModelsAvailable)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                            Text(defaultModelTitle)
                                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(OmniaTheme.Colors.textMuted)
                        }
                        .font(OmniaTheme.Typography.body)
                    }
                    .disabled(state.connections.isEmpty)

                    if state.defaultModelSelection != nil && !defaultSelectionIsAvailable {
                        Label(Localized.invalidDefaultModel, systemImage: "exclamationmark.triangle.fill")
                            .font(OmniaTheme.Typography.secondary)
                            .foregroundStyle(OmniaTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var defaultModelTitle: String {
        guard let selection = state.defaultModelSelection else {
            return Localized.selectDefaultModel
        }
        let provider = state.connections.first {
            $0.identity == selection.provider
        }?.displayName ?? Localized.unavailable
        return "\(provider) · \(selection.model.name)"
    }

    private var defaultSelectionIsAvailable: Bool {
        state.defaultModelSelectionIsAvailable
    }

    /// Explicit per-model overrides for the two multimodal inputs generic
    /// `/models` responses cannot truthfully infer.
    @ViewBuilder
    private var modelCapabilitiesSection: some View {
        if !state.modelCatalogs.isEmpty {
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                SectionHeader(Localized.modelCapabilities)
                ForEach(state.modelCatalogs, id: \.provider) { catalog in
                    Text(providerName(catalog.provider))
                        .font(OmniaTheme.Typography.secondary.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textSecondary)
                    if let status = modelCatalogStatusTitle(catalog.status) {
                        Text(status)
                            .font(OmniaTheme.Typography.caption)
                            .foregroundStyle(OmniaTheme.Colors.textMuted)
                    }
                    ForEach(catalog.models, id: \.selection) { descriptor in
                        OmniaCard {
                            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.sm) {
                                Text(descriptor.selection.model.name)
                                    .font(OmniaTheme.Typography.body.weight(.semibold))
                                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                                capabilityOverrideRow(
                                    Localized.vision,
                                    capability: .vision,
                                    descriptor: descriptor
                                )
                                capabilityOverrideRow(
                                    Localized.documentInput,
                                    capability: .documentInput,
                                    descriptor: descriptor
                                )
                                }
                            }
                        }
                }
            }
        }
    }

    private func providerName(_ identity: ProviderIdentity) -> String {
        state.connections.first { $0.identity == identity }?.displayName
            ?? Localized.unavailable
    }

    private func capabilityOverrideRow(
        _ title: String,
        capability: Capability,
        descriptor: ModelDescriptor
    ) -> some View {
        let current = descriptor.capabilities.support(for: capability)
        return HStack {
            Text(title)
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
            Spacer()
            Menu {
                ForEach(
                    [ModelCapabilitySupport.unknown, .supported, .unsupported],
                    id: \.self
                ) { support in
                    Button {
                        onSetModelCapability(descriptor.selection, capability, support)
                    } label: {
                        HStack {
                            Text(capabilitySupportTitle(support))
                            if current == support { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(capabilitySupportTitle(current))
                    .font(OmniaTheme.Typography.secondary.weight(.medium))
            }
        }
    }

    private func capabilitySupportTitle(_ support: ModelCapabilitySupport) -> String {
        switch support {
        case .unknown: Localized.unknownSupport
        case .supported: Localized.supported
        case .unsupported: Localized.unsupported
        }
    }

    private func modelCatalogStatusTitle(
        _ status: ProviderModelCatalogStatus
    ) -> String? {
        switch status {
        case .loading: Localized.loadingModels
        case .loaded: nil
        case .empty: Localized.noModelsAvailable
        case .configuredFallback: Localized.usingConfiguredModel
        case .cached: Localized.usingCachedModels
        case .unavailable: Localized.usingConfiguredModel
        case .stale: Localized.usingCachedModels
        case .failed: Localized.modelDiscoveryFailed
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
