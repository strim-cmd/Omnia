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
/// The screen is the primary surface of the product (new_design.md §5): the
/// premium dark AI-client hierarchy — message content first, the compact
/// capsule composer, the provider pill, and the light navigation chrome. The
/// view layer isolates all platform code; it is not exercised by the Linux
/// test environment (§3.7) and is verified by review against `project UI
/// standards`.
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
    /// Translates the regenerate intent for the message with the given index.
    public let onRegenerate: (Int) -> Void
    /// Translates the copy intent for the message with the given index.
    public let onCopy: (Int) -> Void
    /// Translates the provider selection intent.
    public let onSelectProvider: (ProviderConnectionListItem) -> Void

    /// The coordinate space of the scroll view, used to measure the viewport
    /// and the bottom marker's position (UX audit U2).
    private let scrollCoordinateSpace = "scroll"
    /// The anchor that triggers auto-scroll to the latest content: a UUID that
    /// changes when a new message arrives or the streaming condition changes
    /// (UX audit U2).
    @State private var autoScrollAnchor = UUID()
    /// The height of the scroll viewport, measured from the scroll view's frame
    /// (UX audit U2).
    @State private var viewportHeight: CGFloat = 0
    /// Whether the bottom marker is near the bottom of the viewport, so the
    /// jump-to-latest affordance is hidden (UX audit U2).
    @State private var isNearBottom = true
    /// The previous streaming condition, used to announce transitions to
    /// VoiceOver (UX audit A4).
    @State private var previousStreamingCondition: ConversationScreenState.StreamingCondition?
    /// The indices of the messages the user has liked, purely presentational
    /// feedback (new_design.md §5).
    @State private var likedMessages = Set<Int>()
    /// The indices of the messages the user has disliked, purely presentational
    /// feedback (new_design.md §5).
    @State private var dislikedMessages = Set<Int>()

    /// Creates a conversation screen view over the given state and intent
    /// callbacks.
    public init(
        state: ConversationScreenState,
        draft: Binding<String>,
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onRegenerate: @escaping (Int) -> Void,
        onCopy: @escaping (Int) -> Void,
        onSelectProvider: @escaping (ProviderConnectionListItem) -> Void
    ) {
        self.state = state
        self._draft = draft
        self.onSend = onSend
        self.onCancel = onCancel
        self.onRegenerate = onRegenerate
        self.onCopy = onCopy
        self.onSelectProvider = onSelectProvider
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            OmniaBackground()

            VStack(spacing: 0) {
                customTopBar
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                            ForEach(state.messages.indices, id: \.self) { index in
                                messageBubble(state.messages[index], index: index)
                            }
                            if case .active = state.streamingCondition {
                                streamingIndicator
                            }
                            streamingBubble
                            bottomMarker
                        }
                        .padding(OmniaTheme.Spacing.lg)
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
        #if os(macOS)
        .toolbarBackground(OmniaTheme.Colors.background, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        #else
        .toolbarBackground(OmniaTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .tint(OmniaTheme.Colors.accent)
        .onChange(of: state.streamingCondition) { condition in
            announceStreamingTransition(from: previousStreamingCondition, to: condition)
            previousStreamingCondition = condition
        }
    }

    /// The custom top bar of the screen: the back button, the conversation
    /// title, and the model indicator pill (new_design.md §5).
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "chevron.left", size: 36, action: {})
                .accessibilityLabel(Text(Localized.back))
            Spacer()
            Text(conversationTitle.isEmpty ? Localized.untitledConversation : conversationTitle)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            modelIndicator
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The model indicator pill of the top bar: the provider icon and the
    /// selected model name (new_design.md §5).
    private var modelIndicator: some View {
        HStack(spacing: OmniaTheme.Spacing.xs) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
            Text(Localized.automatic)
                .font(OmniaTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
        }
        .padding(.horizontal, OmniaTheme.Spacing.md)
        .padding(.vertical, OmniaTheme.Spacing.xs)
        .background(OmniaTheme.Colors.elevatedSurface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
    }

    /// The compact composer of the screen: the attachment button, the message
    /// field, and the send/stop button — a single control roughly 50–60 pt tall
    /// on one line that expands only as needed (new_design.md §5).
    private var composer: some View {
        HStack(alignment: .bottom, spacing: OmniaTheme.Spacing.sm) {
            OmniaIconButton(
                systemImage: "paperclip",
                tint: OmniaTheme.Colors.textSecondary,
                size: 36,
                action: {}
            )
            .accessibilityLabel(Text(Localized.attachment))

            TextField("", text: $draft, prompt: Text(Localized.messagePlaceholder), axis: .vertical)
                .font(OmniaTheme.Typography.body)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .tint(OmniaTheme.Colors.accent)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .frame(minHeight: 50, maxHeight: 150)
                .padding(.vertical, OmniaTheme.Spacing.sm)
                .background(OmniaTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous)
                        .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                )

            if isStreaming {
                OmniaIconButton(
                    systemImage: "stop.circle.fill",
                    tint: OmniaTheme.Colors.accent,
                    size: 40,
                    action: onCancel
                )
                .accessibilityLabel(Text(Localized.stop))
            } else {
                OmniaIconButton(
                    systemImage: "arrow.up.circle.fill",
                    tint: draft.isEmpty ? OmniaTheme.Colors.textMuted : OmniaTheme.Colors.accent,
                    size: 40,
                    action: submit
                )
                .accessibilityLabel(Text(Localized.send))
                .disabled(draft.isEmpty)
            }
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.top, OmniaTheme.Spacing.sm)
        .padding(.bottom, OmniaTheme.Spacing.md)
    }

    private var isStreaming: Bool {
        if case .active = state.streamingCondition {
            return true
        }
        return false
    }

    /// The conversation title of the screen, derived from its content: the
    /// first user message, or the first assistant message when the conversation
    /// has no user message, collapsed to a single line (DES-012 §3.1).
    private var conversationTitle: String {
        let titleMessage = state.messages.first(where: { $0.role == .user })
            ?? state.messages.first(where: { $0.role == .assistant })
        guard let content = titleMessage?.content?.accessibilityText else { return "" }
        return content.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
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
                .padding(.top, OmniaTheme.Spacing.xs)
                .accessibilityLabel(Text(Localized.loadingProviderSelection))
        }
    }

    /// The empty provider state: no provider connection is configured, so the
    /// conversation cannot be served; the row states it plainly and invites
    /// adding a connection in the settings surface (UX audit V2).
    private var emptyProviderSelector: some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.warning)
            Text(Localized.noProviderConnections)
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
            Spacer()
            OmniaButton(
                title: Localized.openSettings,
                systemImage: "gearshape",
                style: .secondary
            ) {}
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.warningSubtle)
    }

    /// The provider picker of the screen: the native pull-down selector of the
    /// configured provider connections, with the current selection's status dot
    /// (new_design.md §5).
    private func providerPicker(_ selection: ConversationScreenState.ProviderSelection) -> some View {
        Menu {
            ForEach(selection.providers, id: \.identity) { item in
                Button {
                    onSelectProvider(item)
                } label: {
                    HStack {
                        Text(item.displayName)
                        Spacer()
                        if selection.selectedItem?.identity == item.identity {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: OmniaTheme.Spacing.sm) {
                Circle()
                    .fill(selectorDotColor(selection))
                    .frame(width: 8, height: 8)
                Text(providerSelectionTitle(selection))
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(OmniaTheme.Typography.secondary.weight(.medium))
            .padding(.horizontal, OmniaTheme.Spacing.lg)
            .padding(.vertical, OmniaTheme.Spacing.sm)
            .background(OmniaTheme.Colors.elevatedSurface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
            )
            .shadow(color: OmniaTheme.Shadows.card, radius: 8, x: 0, y: 2)
        }
        .accessibilityLabel(Text(Localized.providerSelectionCurrent(providerSelectionTitle(selection))))
    }

    /// The status dot of the provider pill: green when the selection can serve
    /// the conversation, amber when the explicit selection is not available
    /// (new_design.md §5).
    private func selectorDotColor(_ selection: ConversationScreenState.ProviderSelection) -> Color {
        if selection.selectedItem != nil, !selection.selectedIsAvailable {
            return OmniaTheme.Colors.warning
        }
        return OmniaTheme.Colors.success
    }

    /// The title of the provider selector: the display name of the selected
    /// provider connection, or "Automatic" when no provider is selected.
    private func providerSelectionTitle(_ selection: ConversationScreenState.ProviderSelection) -> String {
        if let item = selection.selectedItem {
            return item.displayName
        }
        return Localized.automatic
    }

    /// The unavailable provider banner: the selected provider is not available
    /// (e.g., its credential is invalid), so the conversation cannot be served
    /// (UX audit V2).
    private func unavailableProviderBanner(_ item: ProviderConnectionListItem) -> some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.warning)
            Text(Localized.providerUnavailable(item.displayName))
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
            Spacer()
            OmniaButton(
                title: Localized.openSettings,
                systemImage: "gearshape",
                style: .secondary
            ) {}
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.warningSubtle)
    }

    // MARK: Messages

    @ViewBuilder
    private func messageBubble(_ message: MessagePresentation, index: Int) -> some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 48)
                userBubble(message)
            }
        } else {
            HStack {
                assistantBubble(message, index: index)
                Spacer(minLength: 48)
            }
        }
    }

    /// The user message bubble: the purple gradient surface with the message
    /// content (new_design.md §5).
    private func userBubble(_ message: MessagePresentation) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let content = message.content {
                Text(content.accessibilityText)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(Color.white)
                    .padding(OmniaTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(
                        LinearGradient(
                            colors: [
                                OmniaTheme.Colors.userBubbleStart,
                                OmniaTheme.Colors.userBubbleEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous)
                    )
            }
        }
    }

    /// The assistant message bubble: the surface bubble with the message content
    /// and the action buttons (new_design.md §5).
    private func assistantBubble(_ message: MessagePresentation, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let content = message.content {
                Text(content.accessibilityText)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    .padding(OmniaTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OmniaTheme.Colors.surface, in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous))
            }
            if message.role == .assistant {
                HStack(spacing: OmniaTheme.Spacing.sm) {
                    OmniaIconButton(
                        systemImage: "doc.on.doc",
                        tint: OmniaTheme.Colors.textSecondary,
                        size: 28,
                        action: { copy(message) }
                    )
                    .accessibilityLabel(Text(Localized.copy))
                    OmniaIconButton(
                        systemImage: "arrow.clockwise",
                        tint: OmniaTheme.Colors.textSecondary,
                        size: 28,
                        action: { onRegenerate(index) }
                    )
                    .accessibilityLabel(Text(Localized.regenerate))
                }
            }
        }
    }

    /// Translates the copy action of an assistant message: its plain text is
    /// copied to the platform pasteboard — the user's own content (ARC-005).
    private func copy(_ message: MessagePresentation) {
        guard let text = message.content?.accessibilityText else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// Toggles the like action of the message with the given index; liking a
    /// message clears its dislike. Purely presentational feedback
    /// (new_design.md §5).
    private func toggleLike(_ index: Int) {
        if likedMessages.contains(index) {
            likedMessages.remove(index)
        } else {
            likedMessages.insert(index)
            dislikedMessages.remove(index)
        }
    }

    /// Toggles the dislike action of the message with the given index;
    /// disliking a message clears its like.
    private func toggleDislike(_ index: Int) {
        if dislikedMessages.contains(index) {
            dislikedMessages.remove(index)
        } else {
            dislikedMessages.insert(index)
            likedMessages.remove(index)
        }
    }

    // MARK: Streaming

    @ViewBuilder
    private var streamingBubble: some View {
        if case .active(let partialContent) = state.streamingCondition {
            HStack {
                assistantBubble(MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)), index: -1)
                Spacer(minLength: 48)
            }
        } else if case .interrupted(let partialContent) = state.streamingCondition {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    assistantBubble(MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)), index: -1)
                    Spacer(minLength: 48)
                }
                OmniaButton(
                    title: Localized.retry,
                    systemImage: "arrow.clockwise",
                    style: .secondary,
                    action: {}
                )
            }
        }
    }

    /// The streaming indicator: the typing animation shown while a stream is
    /// active (new_design.md §5).
    private var streamingIndicator: some View {
        HStack {
            Image(systemName: "ellipsis.bubble")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            Text(Localized.assistantIsResponding)
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            Spacer()
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
    }

    /// The bottom marker of the scroll view: the invisible view whose position
    /// is measured to determine whether the viewport is near the bottom (UX
    /// audit U2).
    private var bottomMarker: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(key: BottomMarkerPosition.self, value: geometry.frame(in: .named(scrollCoordinateSpace)).minY)
                }
            )
    }

    /// Scrolls the scroll view to the latest content when the auto-scroll
    /// anchor changes and the viewport is near the bottom (UX audit U2).
    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard isNearBottom else { return }
        proxy.scrollTo(autoScrollAnchor, anchor: .bottom)
    }

    /// The jump-to-latest affordance: the button that scrolls to the latest
    /// content when the viewport is not near the bottom (UX audit U2).
    private func jumpToLatest(_ proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation {
                proxy.scrollTo(autoScrollAnchor, anchor: .bottom)
            }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.accent)
                .background(
                    Circle()
                        .fill(OmniaTheme.Colors.accent.opacity(0.2))
                        .frame(width: 56, height: 56)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Localized.jumpToLatest))
        .padding(.bottom, OmniaTheme.Spacing.xl)
    }

    /// The failure banner of the screen: the error condition the screen
    /// presents (DES-012 §3.2).
    private func failureBanner(_ failure: ConversationScreenState.Failure) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
    }

    /// Announces the streaming lifecycle transition to VoiceOver: a response
    /// starting, completing, or being interrupted (UX audit A4).
    private func announceStreamingTransition(
        from previous: ConversationScreenState.StreamingCondition?,
        to current: ConversationScreenState.StreamingCondition?
    ) {
        guard let current else { return }
        let announcement: String
        switch (previous, current) {
        case (nil, .active):
            announcement = StreamingAnnouncement.started
        case (.active, .complete):
            announcement = StreamingAnnouncement.completed
        case (.active, .interrupted):
            announcement = StreamingAnnouncement.interrupted
        default:
            return
        }
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #elseif canImport(AppKit)
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested)
        #endif
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
                return "The request could not be sent. Check your connection settings."
            case .invalidResponse:
                return "The response could not be processed. Check your connection settings."
            case .streamingInterrupted:
                return "The response was interrupted. Please try again."
            }
        }
    }
}

#endif
