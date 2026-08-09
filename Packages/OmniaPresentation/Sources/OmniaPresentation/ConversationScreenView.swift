#if canImport(SwiftUI)

import Foundation
import OmniaApplication
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// The SwiftUI rendering of the conversation screen (DES-012 §3.3): the
/// message history, the streaming condition — the content deltas rendered
/// incrementally as they arrive without blocking the interface, the assembled
/// assistant message on completion, and the preserved partial content of an
/// interruption as incomplete, never discarded (ARC-001) — and the composer
/// that translates the send and cancel intents. The view renders state and
/// translates intent; it owns no business logic (ARC-002).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct ConversationScreenView: View {
    /// The ready-to-render screen state.
    public let state: ConversationScreenState
    /// A binding to the rendered draft of the state, so the composer edits
    /// `state.draft` directly — the draft is not transient view state, and an
    /// unsent draft survives leaving and returning to a conversation because
    /// the shell rehydrates it from the state (UX audit U4).
    @Binding public var draft: String
    /// Translates the send intent with the user's draft text.
    public let onSend: (String) -> Void
    /// Translates the cancel intent while a stream is active.
    public let onCancel: () -> Void
    /// Translates the retry intent of an interrupted response: the preserved
    /// partial content is carried forward into the reply (UX audit U7).
    public let onRetry: () -> Void
    /// Translates the provider-selection intent of the conversation screen: the
    /// user's explicit provider choice, or `nil` for the automatic selection
    /// (UX audit V2).
    public let onSelectProvider: (ProviderIdentity?) -> Void
    /// Translates the open-settings intent of the empty provider state: no
    /// provider connection is configured, so the screen invites adding one in
    /// the settings surface (UX audit V2).
    public let onOpenSettings: () -> Void

    /// The composed position the view keeps the newest content in view on:
    /// `true` while the bottom marker is within the scroll viewport, so
    /// streaming appends auto-scroll only while the user is reading the newest
    /// content and a manual scroll upward is never overridden (UX audit U2).
    @State private var isNearBottom = true
    /// The height of the scroll viewport, reported by the scroll view's frame;
    /// drives the near-bottom determination alongside the bottom marker.
    @State private var viewportHeight: CGFloat = 0
    /// The last rendered streaming condition the screen announced, so the
    /// transition handler announces only the stream lifecycle transitions —
    /// starting, completing, being interrupted — and not every content delta
    /// (UX audit A4).
    @State private var previousStreamingCondition: ConversationScreenState.StreamingCondition?
    /// The bubble and composer inset, scaled with Dynamic Type so the largest
    /// accessibility size stays legible (UX audit V1).
    @ScaledMetric(relativeTo: .body) private var bubblePadding: CGFloat = 10

    /// Creates a conversation screen view over the given state, the draft
    /// binding, and the intent callbacks.
    public init(
        state: ConversationScreenState,
        draft: Binding<String>,
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onSelectProvider: @escaping (ProviderIdentity?) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.state = state
        self._draft = draft
        self.onSend = onSend
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onSelectProvider = onSelectProvider
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            OmniaTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        // A regular (non-lazy) stack so the bottom marker is always
                        // rendered and `scrollTo` can reliably reach it, including
                        // for long histories (UX audit U2).
                        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.m) {
                            ForEach(state.messages.indices, id: \.self) { index in
                                messageBubble(state.messages[index])
                            }
                            streamingBubble
                            bottomMarker
                        }
                        .padding(OmniaTheme.Spacing.l)
                    }
                    .coordinateSpace(name: scrollCoordinateSpace)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollViewportSize.self, value: geometry.size)
                        }
                    )
                    .onPreferenceChange(ScrollViewportSize.self) { size in
                        MainActor.assumeIsolated {
                            viewportHeight = size.height
                        }
                    }
                    .onPreferenceChange(BottomMarkerPosition.self) { position in
                        MainActor.assumeIsolated {
                            guard viewportHeight > 0 else { return }
                            isNearBottom = position <= viewportHeight
                        }
                    }
                    .onChange(of: autoScrollAnchor) { _ in
                        scrollToLatest(proxy)
                    }
                    .overlay(alignment: .bottom) {
                        if !isNearBottom {
                            jumpToLatest(proxy)
                        }
                    }
                }
                if let failure = state.failure {
                    failureBanner(failure)
                }
                providerSelector
                composer
            }
        }
        .onChange(of: state.streamingCondition) { condition in
            announceStreamingTransition(from: previousStreamingCondition, to: condition)
            previousStreamingCondition = condition
        }
    }

    @ViewBuilder
    private var streamingBubble: some View {
        if case .active(let partialContent) = state.streamingCondition {
            HStack {
                MessageBubbleView(
                    message: MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)),
                    roleLabel: Localized.assistantMessage
                )
                Spacer(minLength: 48)
            }
        } else if case .interrupted(let partialContent) = state.streamingCondition {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    MessageBubbleView(
                        message: MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)),
                        roleLabel: Localized.assistantMessage,
                        caption: Localized.interrupted
                    )
                    Spacer(minLength: 48)
                }
                Button(action: onRetry) {
                    Label(Localized.retry, systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(Localized.retryInterruptedResponse))
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: MessagePresentation) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
                MessageBubbleView(message: message, roleLabel: Localized.userMessage)
            } else {
                MessageBubbleView(message: message, roleLabel: Localized.assistantMessage)
                Spacer(minLength: 48)
            }
        }
    }

    /// The minimum and maximum height of the composer, in lines of text.
    private let minComposerLines = 1
    private let maxComposerLines = 6

    /// The line height of the composer's body text on the current platform.
    private func composerLineHeight() -> CGFloat {
        #if canImport(UIKit)
        return UIFont.preferredFont(forTextStyle: .body).lineHeight
        #elseif canImport(AppKit)
        let font = NSFont.preferredFont(forTextStyle: .body)
        return font.ascender - font.descender + font.leading
        #else
        return 17
        #endif
    }

    /// The ideal height of the composer, in points, for the given number of lines.
    private func composerHeight(for lines: Int) -> CGFloat {
        composerLineHeight() * CGFloat(lines) + bubblePadding * 2
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().background(OmniaTheme.Colors.border)
            
            HStack(alignment: .bottom, spacing: OmniaTheme.Spacing.m) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: OmniaTheme.Radii.composer, style: .continuous)
                        .fill(OmniaTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: OmniaTheme.Radii.composer, style: .continuous)
                                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                        )

                    TextField("", text: $draft, axis: .vertical)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: composerLineHeight() + 16, maxHeight: composerHeight(for: maxComposerLines))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .onSubmit {
                            submit()
                        }
                        .accessibilityLabel(Text(Localized.message))
                }

                if isStreaming {
                    Button(action: onCancel) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel(Text(Localized.stop))
                } else {
                    Button(action: submit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(trimmedDraft.isEmpty ? Color.secondary : OmniaTheme.Colors.accentCyan)
                    }
                    .disabled(trimmedDraft.isEmpty)
                    .accessibilityLabel(Text(Localized.send))
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, OmniaTheme.Spacing.l)
            .padding(.vertical, OmniaTheme.Spacing.m)
            .background(OmniaTheme.Colors.background)
        }
        .animation(.easeOut(duration: 0.2), value: isStreaming)
    }

    // MARK: Provider selection (UX audit V2)

    /// The ready-to-render provider selection of the screen: the loading state
    /// while the provider connections have not loaded, the empty state when no
    /// provider connection is configured, the error state when they could not
    /// be loaded, and the native pull-down selector when connections are
    /// present (UX audit V2).
    @ViewBuilder
    private var providerSelector: some View {
        if let selection = state.providerSelection {
            if selection.isEmpty {
                if let failure = selection.failure {
                    failureBanner(failure)
                } else {
                    emptyProviderSelector
                }
            } else {
                providerPicker(selection)
                if let item = selection.selectedItem,
                   !ConversationScreenState.ProviderSelection.isAvailable(item.state) {
                    unavailableProviderBanner(item)
                }
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityLabel(Text(Localized.loadingProviderSelection))
        }
    }

    /// The empty provider state: no provider connection is configured, so the
    /// conversation cannot be served; the row states it plainly and invites
    /// adding a connection in the settings surface (UX audit V2).
    private var emptyProviderSelector: some View {
        HStack(spacing: 8) {
            Label(Localized.noProviderConnections, systemImage: "server.rack")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onOpenSettings) {
                Text(Localized.openSettings)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// The provider selector row: the current selection — the automatic
    /// selection or the selected provider connection — presented as a native
    /// pull-down `Menu`, so the choice is a first-class, accessible affordance
    /// (UI.md, ADR-0001, UX audit V2). A provider connection that is not ready
    /// is presented disabled with its lifecycle state — the frozen selection
    /// policy of DES-009 §3.2 cannot serve it.
    private func providerPicker(_ selection: ConversationScreenState.ProviderSelection) -> some View {
        HStack(spacing: 4) {
            Menu {
                Button {
                    onSelectProvider(nil)
                } label: {
                    if selection.selected == nil {
                        Label(Localized.automatic, systemImage: "checkmark")
                    } else {
                        Text(Localized.automatic)
                    }
                }
                Divider()
                ForEach(selection.providers, id: \.identity) { provider in
                    let available = ConversationScreenState.ProviderSelection.isAvailable(provider.state)
                    Button {
                        onSelectProvider(provider.identity)
                    } label: {
                        HStack(spacing: 6) {
                            if provider.identity == selection.selected {
                                Label(provider.displayName, systemImage: "checkmark")
                            } else {
                                Text(provider.displayName)
                            }
                            if !available {
                                Text(ProviderStateLabel.label(for: provider.state))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!available)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                    Text(providerSelectionTitle(selection))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.subheadline)
                .padding(6)
            }
            .accessibilityLabel(Text(Localized.providerSelectionCurrent(providerSelectionTitle(selection))))
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    /// The title of the provider selector: the display name of the selected
    /// provider connection, or "Automatic" when no provider is selected.
    private func providerSelectionTitle(_ selection: ConversationScreenState.ProviderSelection) -> String {
        if let item = selection.selectedItem {
            return item.displayName
        }
        return Localized.automatic
    }

    /// The warning banner presenting a selected provider connection that is not
    /// available: the frozen selection policy skips a selection that is not
    /// selectable and applies the automatic selection (DES-009 §3.2), so the
    /// screen announces that the explicit choice is not being served — never
    /// silent (ARC-001, UX audit V2).
    private func unavailableProviderBanner(_ item: ProviderConnectionListItem) -> some View {
        let message = Localized.providerUnavailable(item.displayName)
        return ErrorBannerView(message: message, backgroundColor: .orange)
            .padding(.top, 4)
    }

    /// Translates the send intent with the drafted text: Return-key send and
    /// the send button both route here, so one path governs the guard — an
    /// empty or whitespace draft is not sent, and while a stream is active the
    /// Stop affordance takes over (UX audit U1).
    private func submit() {
        guard !isStreaming, !trimmedDraft.isEmpty else { return }
        onSend(draft)
        draft = ""
    }

    /// The value that changes whenever the newest content advances: the message
    /// count and the length of the streaming partial content. Drives the
    /// auto-scroll (UX audit U2).
    private var autoScrollAnchor: String {
        if case .active(let partialContent) = state.streamingCondition {
            return "\(state.messages.count)-\(partialContent.count)"
        }
        return "\(state.messages.count)"
    }

    /// Scrolls the newest content into view on send and on streaming appends,
    /// only while the user is reading the newest content — a manual scroll
    /// upward is never overridden (UX audit U2).
    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard isNearBottom else { return }
        withAnimation {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    private func jumpToLatest(_ proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } label: {
            Label(Localized.jumpToLatest, systemImage: "arrow.down")
                .font(.subheadline)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(OmniaTheme.Colors.surface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Localized.jumpToLatest))
        .padding(.bottom, OmniaTheme.Spacing.m)
    }

    /// The invisible last element of the scroll content: the anchor the
    /// auto-scroll and the jump-to-latest scroll to, whose position in the
    /// scroll coordinate space determines whether the newest content is in
    /// view (UX audit U2).
    private var bottomMarker: some View {
        Color.clear
            .frame(height: 1)
            .id(bottomAnchor)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: BottomMarkerPosition.self,
                        value: geometry.frame(in: .named(scrollCoordinateSpace)).minY
                    )
                }
            )
    }

    private var isStreaming: Bool {
        if case .active = state.streamingCondition {
            return true
        }
        return false
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func failureBanner(_ failure: ConversationScreenState.Failure) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
            .padding(.top, 4)
    }

    /// Announces the streaming lifecycle for VoiceOver — a response starting,
    /// completing, or being interrupted — so a VoiceOver user hears whether a
    /// response is forming versus finished (UX audit A4). Content deltas
    /// continue without re-announcing, and a stream that ends in a failure
    /// announces the failure message the banner presents, never silent
    /// (ARC-001).
    private func announceStreamingTransition(
        from previous: ConversationScreenState.StreamingCondition?,
        to current: ConversationScreenState.StreamingCondition?
    ) {
        switch current {
        case .active:
            if case .active = previous {
                return
            }
            announce(StreamingAnnouncement.started)
        case .complete:
            announce(StreamingAnnouncement.completed)
        case .interrupted:
            announce(StreamingAnnouncement.interrupted)
        case nil:
            if case .active = previous, let failure = state.failure {
                announce(FailureCopy.message(for: failure))
            }
        }
    }

    /// Posts an accessibility announcement: VoiceOver announces `text` on iOS
    /// and macOS, without moving the focus or affecting selection (UX audit
    /// A4). The platform call is isolated here in the view layer, which is
    /// Apple-platform code (DES-012 §3.7).
    private func announce(_ text: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: text)
        #elseif canImport(AppKit)
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
        #endif
    }

    /// The identifier of the scroll-content bottom marker, and the named
    /// coordinate space the marker's position is reported in.
    private let bottomAnchor = "conversation-screen-bottom"
    private let scrollCoordinateSpace = "conversation-screen-scroll"
}

/// The preference carrying the bottom marker's position in the scroll
/// coordinate space; `minY` is the distance of the marker from the top of the
/// viewport, so the newest content is in view while it does not exceed the
/// viewport height (UX audit U2).
private struct BottomMarkerPosition: PreferenceKey {
    static var defaultValue: CGFloat { .greatestFiniteMagnitude }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

/// The preference carrying the scroll viewport size, measured from the scroll
/// view's frame; drives the near-bottom determination (UX audit U2).
private struct ScrollViewportSize: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// The accessibility announcement copy for the streaming lifecycle the screen
/// announces — a response starting, completing, or being interrupted — so a
/// VoiceOver user hears whether a response is forming versus finished (UX
/// audit A4).
private enum StreamingAnnouncement {
    static let started = "Assistant is responding."
    static let completed = "Response complete."
    static let interrupted = "Response interrupted."
}

/// User-facing copy for the typed failures the presentation views present —
/// view-layer text derived from the typed error, never raw error detail
/// (ARC-005). The failure is presented as it is, never silent (ARC-001): the
/// banner text and its accessibility label both carry the message (UX audit
/// A2/S2).
enum FailureCopy {

    static func message(for failure: RepositoryError) -> String {
        switch failure {
        case .storageUnavailable:
            return "Storage is temporarily unavailable. Please try again."
        }
    }

    static func message(for failure: ApplicationValidationError) -> String {
        switch failure {
        case .invalid(let reason):
            return reason
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

    static func message(for failure: CapabilityError) -> String {
        switch failure {
        case .providerUnavailable:
            return "No provider is available. Check your connection settings."
        case .invalidRequest:
            return "The request could not be sent."
        case .invalidResponse:
            return "The provider returned an unexpected response."
        case .streamingInterrupted:
            return "The response was interrupted before it finished."
        }
    }

    static func message(for failure: ConversationScreenState.Failure) -> String {
        switch failure {
        case .application(let error):
            return message(for: error)
        case .repository(let error):
            return message(for: error)
        case .capability(let error):
            return message(for: error)
        case .credentialStorage(let error):
            return message(for: error)
        case .unexpected:
            return "An unexpected error occurred. Please try again."
        }
    }

    static func message(for failure: SettingsState.Failure) -> String {
        switch failure {
        case .application(let error):
            return message(for: error)
        case .repository(let error):
            return message(for: error)
        case .credentialStorage(let error):
            return message(for: error)
        }
    }
}

/// The generic lifecycle state label of a provider connection — the rendering
/// of the Domain `ProviderState` shared by the views that present provider
/// connections, never provider-specific (ARC-004).
enum ProviderStateLabel {
    static func label(for state: ProviderState) -> String {
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
