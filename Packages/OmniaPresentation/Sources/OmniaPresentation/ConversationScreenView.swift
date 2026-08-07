#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

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
    /// Translates the send intent with the user's draft text.
    public let onSend: (String) -> Void
    /// Translates the cancel intent while a stream is active.
    public let onCancel: () -> Void

    @State private var draft = ""

    /// Creates a conversation screen view over the given state and intent
    /// callbacks.
    public init(
        state: ConversationScreenState,
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.state = state
        self.onSend = onSend
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.messages.indices, id: \.self) { index in
                        messageBubble(state.messages[index])
                    }
                    streamingBubble
                }
                .padding()
            }
            if let failure = state.failure {
                failureBanner(failure)
            }
            composer
        }
    }

    @ViewBuilder
    private var streamingBubble: some View {
        if case .active(let partialContent) = state.streamingCondition {
            assistantBubble(partialContent, caption: nil)
        } else if case .interrupted(let partialContent) = state.streamingCondition {
            assistantBubble(partialContent, caption: Text("Interrupted"))
        }
    }

    private func messageBubble(_ message: MessagePresentation) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                bubbleContent(message, accessibilityLabel: Text("User message"))
            }
        case .assistant, .system:
            HStack {
                bubbleContent(message, accessibilityLabel: Text("Assistant message"))
                Spacer(minLength: 48)
            }
        }
    }

    private func bubbleContent(
        _ message: MessagePresentation,
        accessibilityLabel: @autoclosure () -> Text
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let content = message.content {
                MarkdownView(content: content)
            }
        }
        .padding(10)
        .background(message.role == .user ? Color.accentColor : Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(message.role == .user ? Color.white : Color.primary)
        .accessibilityLabel(accessibilityLabel())
    }

    private func assistantBubble(_ content: String, caption: Text?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                MarkdownView(content: MarkdownContent(markdown: content))
                if let caption {
                    caption
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(caption ?? Text("Assistant message"))
            Spacer(minLength: 48)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Stop"))
            } else {
                Button {
                    onSend(draft)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(trimmedDraft.isEmpty)
                .accessibilityLabel(Text("Send"))
            }
        }
        .padding()
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
        Label("Something went wrong. Please try again.", systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.top, 4)
            .accessibilityLabel(Text("Error"))
    }
}

#endif
