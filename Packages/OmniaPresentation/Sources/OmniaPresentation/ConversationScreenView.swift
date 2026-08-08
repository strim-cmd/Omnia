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
/// review against `.ai/standards/UI.md`.
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
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self._draft = draft
        self.onSend = onSend
        self.onCancel = onCancel
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    // A regular (non-lazy) stack so the bottom marker is always
                    // rendered and `scrollTo` can reliably reach it, including
                    // for long histories (UX audit U2).
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(state.messages.indices, id: \.self) { index in
                            messageBubble(state.messages[index])
                        }
                        streamingBubble
                        bottomMarker
                    }
                    .padding()
                }
                .coordinateSpace(name: scrollCoordinateSpace)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: ScrollViewportSize.self, value: geometry.size)
                    }
                )
                .onPreferenceChange(ScrollViewportSize.self) { size in
                    viewportHeight = size.height
                }
                .onPreferenceChange(BottomMarkerPosition.self) { position in
                    guard viewportHeight > 0 else { return }
                    isNearBottom = position <= viewportHeight
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
            composer
        }
        .onChange(of: state.streamingCondition) { condition in
            announceStreamingTransition(from: previousStreamingCondition, to: condition)
            previousStreamingCondition = condition
        }
    }

    @ViewBuilder
    private var streamingBubble: some View {
        if case .active(let partialContent) = state.streamingCondition {
            assistantBubble(partialContent, caption: nil)
        } else if case .interrupted(let partialContent) = state.streamingCondition {
            VStack(alignment: .leading, spacing: 6) {
                assistantBubble(partialContent, caption: "Interrupted")
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Retry the interrupted response"))
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: MessagePresentation) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                bubbleContent(message, roleLabel: "User message")
            }
        case .assistant, .system:
            HStack {
                bubbleContent(message, roleLabel: "Assistant message")
                Spacer(minLength: 48)
            }
        }
    }

    /// A history message bubble with one consistent accessibility strategy: the
    /// whole bubble is a single logical element whose label reads the role
    /// followed by the content — the same for user and assistant messages (UX
    /// audit A3).
    private func bubbleContent(
        _ message: MessagePresentation,
        roleLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let content = message.content {
                MarkdownView(content: content)
            }
        }
        .padding(bubblePadding)
        .background(message.role == .user ? Color.accentColor : Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(message.role == .user ? userBubbleTextColor() : Color.primary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(messageAccessibilityLabel(roleLabel: roleLabel, content: message.content)))
    }

    /// The text color that meets WCAG AA contrast against the user bubble's
    /// `Color.accentColor` background in the current color scheme and
    /// increased-contrast mode (UX audit V1): white for dark accents, black
    /// for light accents, chosen by relative luminance rather than fixed
    /// white.
    private static func userBubbleTextColor() -> Color {
        guard let components = accentRGBComponents() else { return .white }
        switch BubbleTextColor.contrasting(
            backgroundRed: components.red,
            green: components.green,
            blue: components.blue
        ) {
        case .white:
            return .white
        case .black:
            return .black
        }
    }

    /// The sRGB components of the resolved accent color, or `nil` when the
    /// platform cannot expose them as RGB.
    private static func accentRGBComponents() -> (red: Double, green: Double, blue: Double)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let resolved: Bool
        #if canImport(UIKit)
        resolved = UIColor(Color.accentColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        let accent = NSColor(Color.accentColor)
        resolved = (accent.usingColorSpace(.sRGB) ?? accent)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        resolved = false
        #endif
        guard resolved else { return nil }
        return (red: Double(red), green: Double(green), blue: Double(blue))
    }

    /// The streaming/interrupted bubble: one logical accessibility element
    /// reading the role, the interruption status when present, and the
    /// preserved partial content (UX audit A3).
    private func assistantBubble(_ content: String, caption: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                MarkdownView(content: MarkdownContent(markdown: content))
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(bubblePadding)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(assistantAccessibilityLabel(content: content, caption: caption)))
            Spacer(minLength: 48)
        }
    }

    /// The bubble label composed of the role followed by the content, so
    /// VoiceOver reads every history bubble as one logical element — role then
    /// content — consistently (UX audit A3).
    private func messageAccessibilityLabel(roleLabel: String, content: MarkdownContent?) -> String {
        var parts = [roleLabel]
        if let content {
            let text = accessibilityText(content)
            if !text.isEmpty {
                parts.append(text)
            }
        }
        return parts.joined(separator: ", ")
    }

    /// The streaming/interrupted bubble label: the role, the interruption
    /// status when present, then the preserved partial content (UX audit A3).
    private func assistantAccessibilityLabel(content: String, caption: String?) -> String {
        var parts = ["Assistant message"]
        if let caption {
            parts.append(caption)
        }
        let text = accessibilityText(MarkdownContent(markdown: content))
        if !text.isEmpty {
            parts.append(text)
        }
        return parts.joined(separator: ", ")
    }

    /// The plain-text reading of markdown content for an accessibility label:
    /// prose text as rendered (markdown syntax stripped, matching
    /// `MarkdownView`) and code content verbatim, so the announced label reads
    /// the way the bubble is displayed (UX audit A3).
    private func accessibilityText(_ content: MarkdownContent) -> String {
        content.segments.map { segment in
            switch segment {
            case .text(let text):
                return (try? AttributedString(markdown: text))?.description ?? text
            case .codeBlock(let code):
                return code
            }
        }
        .joined(separator: "\n")
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

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft)
                .textFieldStyle(.plain)
                .padding(bubblePadding)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit(submit)
                .submitLabel(.send)
            if isStreaming {
                Label("Responding…", systemImage: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Stop"))
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(trimmedDraft.isEmpty)
                .accessibilityLabel(Text("Send"))
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
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
            Label("Jump to Latest", systemImage: "arrow.down")
                .font(.subheadline)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Jump to Latest"))
        .padding(.bottom, 8)
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
        let message = FailureCopy.message(for: failure)
        return Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.top, 4)
            .accessibilityLabel(Text(message))
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
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

/// The preference carrying the scroll viewport size, measured from the scroll
/// view's frame; drives the near-bottom determination (UX audit U2).
private struct ScrollViewportSize: PreferenceKey {
    static var defaultValue: CGSize = .zero
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

#endif
