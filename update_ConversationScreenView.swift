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
            providerSelector
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
                assistantBubble(partialContent, caption: Localized.interrupted)
                Button(action: onRetry) {
                    Label(Localized.retry, systemImage: "arrow.clockwise")
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
                bubbleContent(message, roleLabel: Localized.userMessage)
            }
        case .assistant, .system:
            HStack {
                bubbleContent(message, roleLabel: Localized.assistantMessage)
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
        .foregroundStyle(message.role == .u
