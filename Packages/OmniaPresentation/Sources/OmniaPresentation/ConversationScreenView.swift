#if canImport(SwiftUI)

import Foundation
import OmniaApplication
import SwiftUI
#if canImport(CoreTransferable)
import CoreTransferable
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

#if canImport(CoreTransferable) && canImport(PhotosUI) && canImport(UniformTypeIdentifiers)
/// Requests a file representation from PhotosPicker and reads only one byte
/// beyond the explicit limit. The temporary URL never escapes this transfer.
private struct BoundedPhotoTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let maximumByteCount = AttachmentLimits().maximumFileBytes
            guard maximumByteCount >= 0, maximumByteCount < Int.max else {
                throw AttachmentError.storageUnavailable
            }
            do {
                let handle = try FileHandle(forReadingFrom: received.file)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumByteCount + 1) ?? Data()
                guard !data.isEmpty else {
                    throw AttachmentError.empty(fileName: "Photo")
                }
                guard data.count <= maximumByteCount else {
                    throw AttachmentError.fileTooLarge(
                        fileName: "Photo",
                        limit: maximumByteCount
                    )
                }
                return BoundedPhotoTransfer(data: data)
            } catch let error as AttachmentError {
                throw error
            } catch {
                throw AttachmentError.unreadable(fileName: "Photo")
            }
        }
    }
}
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
    /// Translates the retry intent when a request fails.
    public let onRetry: () -> Void
    /// Translates the copy intent for the message with the given index.
    public let onCopy: (Int) -> Void
    /// Translates the provider selection intent.
    public let onSelectModel: (ProviderModelSelection) -> Void
    /// Translates the open-providers intent of the provider banners — the
    /// empty and unavailable provider rows route to the providers surface
    /// through the shell's normal navigation (UX audit P2).
    public let onOpenProviders: () -> Void
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void
    /// Imports security-scoped file-picker URLs into app-owned storage.
    public let onAddFiles: ([URL]) -> Void
    /// Imports in-memory photo-picker candidates into app-owned storage.
    public let onStageAttachments: ([AttachmentImportCandidate]) -> Void
    /// Removes one staged app-owned attachment.
    public let onRemoveAttachment: (MessageAttachment) -> Void
    /// Presents a safe picker/transfer failure without discarding the draft.
    public let onAttachmentFailure: (AttachmentError) -> Void
    /// Dismisses a terminal error without changing messages, draft, staged
    /// attachments, or streaming state.
    public let onDismissFailure: () -> Void

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
    /// The waveform pulse of the streaming indicator, toggled so the bars
    /// animate while a stream is active or thinking (new_design.md §5).
    @State private var waveformPulse = false
    @State private var isFileImporterPresented = false
    @State private var isModelSelectionPresented = false
    #if canImport(PhotosUI)
    @State private var selectedPhotos: [PhotosPickerItem] = []
    #endif
    /// Whether the composer owns keyboard focus. Focus is presentation-only:
    /// dismissing it never mutates the bound draft.
    @FocusState private var isComposerFocused: Bool

    /// Creates a conversation screen view over the given state and intent
    /// callbacks.
    public init(
        state: ConversationScreenState,
        draft: Binding<String>,
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onRegenerate: @escaping (Int) -> Void,
        onRetry: @escaping () -> Void,
        onCopy: @escaping (Int) -> Void,
        onSelectModel: @escaping (ProviderModelSelection) -> Void,
        onOpenProviders: @escaping () -> Void,
        onOpenMenu: @escaping () -> Void,
        onAddFiles: @escaping ([URL]) -> Void = { _ in },
        onStageAttachments: @escaping ([AttachmentImportCandidate]) -> Void = { _ in },
        onRemoveAttachment: @escaping (MessageAttachment) -> Void = { _ in },
        onAttachmentFailure: @escaping (AttachmentError) -> Void = { _ in },
        onDismissFailure: @escaping () -> Void = {}
    ) {
        self.state = state
        self._draft = draft
        self.onSend = onSend
        self.onCancel = onCancel
        self.onRegenerate = onRegenerate
        self.onRetry = onRetry
        self.onCopy = onCopy
        self.onSelectModel = onSelectModel
        self.onOpenProviders = onOpenProviders
        self.onOpenMenu = onOpenMenu
        self.onAddFiles = onAddFiles
        self.onStageAttachments = onStageAttachments
        self.onRemoveAttachment = onRemoveAttachment
        self.onAttachmentFailure = onAttachmentFailure
        self.onDismissFailure = onDismissFailure
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            OmniaBackground()

            VStack(spacing: 0) {
                customTopBar
                providerSelector
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.md) {
                            if state.messages.isEmpty {
                                emptyConversationState
                            } else {
                                todayMarker
                                ForEach(state.messages.indices, id: \.self) { index in
                                    messageBubble(state.messages[index], index: index)
                                }
                            }
                            streamingStateCard
                            streamingBubble
                            bottomMarker
                        }
                        .padding(OmniaTheme.Spacing.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isComposerFocused = false
                        }
                    )
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
                    errorState(failure)
                }
                composer
            }
        }
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #else
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .tint(OmniaTheme.Colors.accent)
        .onChange(of: state.streamingCondition) { condition in
            announceStreamingTransition(from: previousStreamingCondition, to: condition)
            previousStreamingCondition = condition
        }
        .confirmationDialog(
            Localized.changeModel,
            isPresented: $isModelSelectionPresented,
            titleVisibility: .visible
        ) {
            modelSelectionActions
        }
        #if canImport(PhotosUI)
        .onChange(of: selectedPhotos) { items in
            loadPhotos(items)
        }
        #endif
        #if canImport(UniformTypeIdentifiers)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .pdf, .plainText, .text, .data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                onAddFiles(urls)
            } else if case .failure(let error) = result,
                      !(error is CancellationError),
                      (error as? CocoaError)?.code != .userCancelled {
                onAttachmentFailure(.unreadable(fileName: "Attachment"))
            }
        }
        #endif
    }

    /// The custom top bar of the screen: the menu button and centered
    /// conversation title. Creating a conversation belongs to the conversation
    /// list; this active-chat surface keeps an equal trailing layout spacer
    /// instead of exposing a redundant, inert compose control.
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: onOpenMenu)
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(conversationTitle.isEmpty ? Localized.newConversation : conversationTitle)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            Color.clear
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The compact composer: an independent 44-point attachment circle beside
    /// a 46-point input capsule whose trailing edge contains the 34-point
    /// send/stop circle. The capsule expands only as multiline input needs it.
    private var composer: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.xs) {
            if !state.draftAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OmniaTheme.Spacing.sm) {
                        ForEach(state.draftAttachments, id: \.identity) { attachment in
                            attachmentChip(attachment)
                        }
                    }
                }
            }
            if let issue = state.attachmentIssue {
                Text(Localized.attachmentError(issue))
                    .font(OmniaTheme.Typography.secondary)
                    .foregroundStyle(OmniaTheme.Colors.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(Localized.attachmentError(issue)))
            }
            HStack(alignment: .bottom, spacing: OmniaTheme.Spacing.sm) {
                attachmentPicker

                ZStack(alignment: .bottomTrailing) {
                    TextField(
                        "",
                        text: $draft,
                        prompt: Text(Localized.messagePlaceholder)
                            .foregroundColor(OmniaTheme.Colors.textMuted),
                        axis: .vertical
                    )
                        .font(OmniaTheme.Typography.body)
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                        .tint(OmniaTheme.Colors.accent)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .frame(minHeight: 46, alignment: .center)
                        .padding(.leading, OmniaTheme.Spacing.md)
                        .padding(.trailing, 50)
                        .focused($isComposerFocused)

                    composerActionButton
                        .padding(1)
                }
                .background(OmniaTheme.Colors.elevatedSurface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                )
                .shadow(color: OmniaTheme.Shadows.composer, radius: 10, x: 0, y: 4)
            }
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.top, OmniaTheme.Spacing.sm)
        .padding(.bottom, OmniaTheme.Spacing.md)
    }

    @ViewBuilder
    private var attachmentPicker: some View {
        Menu {
            #if canImport(PhotosUI)
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 8,
                matching: .images
            ) {
                Label(Localized.addPhotos, systemImage: "photo.on.rectangle")
            }
            #endif
            #if canImport(UniformTypeIdentifiers)
            Button {
                isFileImporterPresented = true
            } label: {
                Label(Localized.addFiles, systemImage: "doc")
            }
            #endif
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(OmniaTheme.Colors.elevatedSurface, in: Circle())
                .overlay(Circle().stroke(OmniaTheme.Colors.border, lineWidth: 0.5))
        }
        .accessibilityLabel(Text(Localized.attachment))
        .disabled(isStreaming)
        .padding(.bottom, 1)
    }

    private func attachmentChip(_ attachment: MessageAttachment) -> some View {
        HStack(spacing: OmniaTheme.Spacing.xs) {
            Image(systemName: attachmentIcon(attachment.kind))
                .foregroundStyle(OmniaTheme.Colors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.fileName)
                    .lineLimit(1)
                Text(
                    attachment.mediaType + " · " + ByteCountFormatter.string(
                        fromByteCount: Int64(attachment.byteCount),
                        countStyle: .file
                    )
                )
                .font(OmniaTheme.Typography.caption)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            }
            Button {
                onRemoveAttachment(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(OmniaTheme.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Localized.removeAttachment(attachment.fileName)))
        }
        .font(OmniaTheme.Typography.secondary)
        .padding(.leading, OmniaTheme.Spacing.sm)
        .padding(.trailing, OmniaTheme.Spacing.xs)
        .padding(.vertical, OmniaTheme.Spacing.xs)
        .background(OmniaTheme.Colors.elevatedSurface, in: Capsule())
        .overlay(Capsule().stroke(OmniaTheme.Colors.border, lineWidth: 0.5))
    }

    private var composerActionButton: some View {
        Button(action: isStreaming ? onCancel : submit) {
            ZStack {
                Circle()
                    .fill(composerActionFill)
                    .frame(width: 34, height: 34)
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(composerActionForeground)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isStreaming ? Localized.stop : Localized.send))
        .disabled(!isStreaming && !canSend)
    }

    private var composerActionFill: Color {
        if isStreaming || canSend {
            return OmniaTheme.Colors.accent
        }
        return OmniaTheme.Colors.textMuted.opacity(0.18)
    }

    private var composerActionForeground: Color {
        isStreaming || canSend
            ? OmniaTheme.Colors.userBubbleText
            : OmniaTheme.Colors.textMuted
    }

    private var isStreaming: Bool {
        switch state.streamingCondition {
        case .active, .thinking:
            return true
        case .interrupted, .complete, .none:
            return false
        }
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

    /// Sending requires a non-empty draft and the exact persisted provider/model
    /// pair to be currently selectable. An unavailable saved model keeps the
    /// draft intact until the user explicitly chooses a replacement.
    private var canSend: Bool {
        guard !trimmedDraft.isEmpty || !state.draftAttachments.isEmpty else { return false }
        guard state.attachmentIssue == nil else { return false }
        guard let selection = state.providerSelection else { return false }
        return selection.selectedModel != nil && selection.selectedIsAvailable
    }

    /// Translates the send intent with the drafted text: the send button routes
    /// here, so one path governs the guard — an empty or whitespace draft is not
    /// sent, and while a stream is active the Stop affordance takes over (UX
    /// audit U1).
    private func submit() {
        guard !isStreaming, canSend else { return }
        onSend(draft)
    }

    #if canImport(PhotosUI)
    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var candidates: [AttachmentImportCandidate] = []
            var failure: AttachmentError?
            for (index, item) in items.enumerated() {
                do {
                    guard let transfer = try await item.loadTransferable(
                        type: BoundedPhotoTransfer.self
                    ) else {
                        failure = .unreadable(fileName: "Photo-\(index + 1)")
                        break
                    }
                    candidates.append(
                        AttachmentImportCandidate(
                            data: transfer.data,
                            fileName: "Photo-\(index + 1)"
                        )
                    )
                } catch let error as AttachmentError {
                    failure = error
                    break
                } catch {
                    failure = .unreadable(fileName: "Photo-\(index + 1)")
                    break
                }
            }
            await MainActor.run {
                if let failure {
                    onAttachmentFailure(failure)
                } else if !candidates.isEmpty {
                    onStageAttachments(candidates)
                }
                selectedPhotos = []
            }
        }
    }
    #endif

    // MARK: Provider selection (UX audit V2)

    @ViewBuilder
    private var modelSelectionActions: some View {
        if let selection = state.providerSelection {
            ForEach(selection.modelCatalogs, id: \.provider) { catalog in
                ForEach(catalog.models, id: \.selection) { descriptor in
                    Button(
                        "\(providerName(catalog.provider, in: selection)) — \(descriptor.selection.model.name)"
                    ) {
                        onSelectModel(descriptor.selection)
                    }
                    .disabled(
                        selection.providers.first { $0.identity == catalog.provider }
                            .map { !ConversationScreenState.ProviderSelection.isAvailable($0.state) }
                            ?? true
                    )
                }
            }
        }
        Button(Localized.cancel, role: .cancel) {}
    }

    private func providerName(
        _ identity: ProviderIdentity,
        in selection: ConversationScreenState.ProviderSelection
    ) -> String {
        selection.providers.first { $0.identity == identity }?.displayName
            ?? Localized.unavailable
    }

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
                } else if let selectedModel = selection.selectedModel,
                          !selection.selectedIsAvailable {
                    unavailableModelBanner(selectedModel)
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
    /// conversation cannot be served; the row states it plainly and its Open
    /// Providers button routes to the providers surface to add a connection
    /// (UX audit V2, P2).
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
                title: Localized.openProviders,
                systemImage: "globe",
                style: .secondary,
                action: onOpenProviders
            )
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.warningSubtle)
    }

    /// The provider picker of the screen: the native pull-down selector of the
    /// configured provider connections, with the current selection's status dot
    /// (new_design.md §5).
    private func providerPicker(_ selection: ConversationScreenState.ProviderSelection) -> some View {
        HStack {
            Spacer(minLength: 0)
            Menu {
                ForEach(selection.providers, id: \.identity) { item in
                    Menu(item.displayName) {
                        let catalog = selection.modelCatalogs.first {
                            $0.provider == item.identity
                        }
                        if let catalog, !catalog.models.isEmpty {
                            ForEach(catalog.models, id: \.selection) { descriptor in
                                Button {
                                    onSelectModel(descriptor.selection)
                                } label: {
                                    HStack {
                                        Text(descriptor.selection.model.name)
                                        if selection.selectedModel == descriptor.selection {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .disabled(!ConversationScreenState.ProviderSelection.isAvailable(item.state))
                            }
                        } else {
                            Text(Localized.noModelsAvailable)
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
            Spacer(minLength: 0)
        }
        .padding(.top, OmniaTheme.Spacing.sm)
        .disabled(isStreaming)
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
        if let item = selection.selectedItem, let model = selection.selectedModel?.model {
            return "\(item.displayName) · \(model.name)"
        }
        if let item = selection.selectedItem {
            return item.displayName
        }
        return Localized.automatic
    }

    /// The unavailable provider banner: the selected provider is not available
    /// (e.g., its credential is invalid), so the conversation cannot be served;
    /// its Open Providers button routes to the providers surface (UX audit V2, P2).
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
                title: Localized.openProviders,
                systemImage: "globe",
                style: .secondary,
                action: onOpenProviders
            )
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.warningSubtle)
    }

    // MARK: Messages

    /// The empty conversation state: the hero of a brand-new conversation with
    /// no messages — the product invites the first prompt (new_design.md §5).
    private var emptyConversationState: some View {
        VStack(spacing: OmniaTheme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.accent)
                .shadow(color: OmniaTheme.Colors.glowPurple, radius: 20)
                .shadow(color: OmniaTheme.Colors.glowCyan, radius: 32)
            Text(Localized.startNewConversation)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(Localized.startNewConversationDescription)
                .font(OmniaTheme.Typography.body)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, OmniaTheme.Spacing.xxl * 4)
        .padding(.horizontal, OmniaTheme.Spacing.xl)
    }

    /// The today marker: the day divider at the top of the message history that
    /// anchors the newest content (new_design.md §5).
    /// The "Today" date marker shown in the conversation (CHAT.md).
    private var todayMarker: some View {
        HStack(spacing: OmniaTheme.Spacing.md) {
            Capsule()
                .fill(OmniaTheme.Colors.border)
                .frame(height: 1)
            Text(Localized.today)
                .font(OmniaTheme.Typography.caption)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            Capsule()
                .fill(OmniaTheme.Colors.border)
                .frame(height: 1)
        }
        .padding(.horizontal, OmniaTheme.Spacing.md)
        .padding(.vertical, OmniaTheme.Spacing.sm)
    }

    /// The assistant message action row: copy, like, dislike, and more (COMPONENTS.md).
    private func assistantActionRow(for message: MessagePresentation, index: Int) -> some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            OmniaIconButton(
                systemImage: "doc.on.doc",
                tint: OmniaTheme.Colors.textSecondary,
                size: 28,
                action: { onCopy(index) }
            )
            .accessibilityLabel(Text(Localized.copy))

            OmniaIconButton(
                systemImage: likedMessages.contains(index) ? "hand.thumbsup.fill" : "hand.thumbsup",
                tint: likedMessages.contains(index) ? OmniaTheme.Colors.accent : OmniaTheme.Colors.textSecondary,
                size: 28,
                action: { toggleLike(index) }
            )
            .accessibilityLabel(Text(Localized.like))

            OmniaIconButton(
                systemImage: dislikedMessages.contains(index) ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                tint: dislikedMessages.contains(index) ? OmniaTheme.Colors.accent : OmniaTheme.Colors.textSecondary,
                size: 28,
                action: { toggleDislike(index) }
            )
            .accessibilityLabel(Text(Localized.dislike))

            Spacer(minLength: 0)

            Menu {
                Button {
                    onRegenerate(index)
                } label: {
                    Label(Localized.regenerate, systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            }
            .accessibilityLabel(Text(Localized.more))
        }
        .padding(.horizontal, OmniaTheme.Spacing.md)
        .padding(.bottom, OmniaTheme.Spacing.xs)
    }

    @ViewBuilder
    private func messageBubble(_ message: MessagePresentation, index: Int) -> some View {
        if message.role == .user {
            AdaptiveMessageBubbleRowLayout(edge: .trailing) {
                userBubble(message)
            }
        } else {
            AdaptiveMessageBubbleRowLayout(edge: .leading) {
                assistantBubble(message, index: index)
            }
        }
    }

    /// The user message bubble: the purple gradient surface with the message
    /// content (new_design.md §5).
    private func userBubble(_ message: MessagePresentation) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if message.content != nil || !message.attachments.isEmpty {
                VStack(alignment: .leading, spacing: OmniaTheme.Spacing.sm) {
                    if let content = message.content {
                        Text(content.accessibilityText)
                            .font(OmniaTheme.Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(message.attachments, id: \.identity) { attachment in
                        HStack(spacing: OmniaTheme.Spacing.xs) {
                            Image(systemName: attachmentIcon(attachment.kind))
                            Text(attachment.fileName).lineLimit(1)
                            Text(
                                attachment.mediaType + " · " + ByteCountFormatter.string(
                                    fromByteCount: Int64(attachment.byteCount),
                                    countStyle: .file
                                )
                            )
                            .opacity(0.72)
                        }
                        .font(OmniaTheme.Typography.secondary)
                        .accessibilityElement(children: .combine)
                    }
                }
                .foregroundStyle(Color.white)
                .padding(OmniaTheme.Spacing.md)
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

    private func attachmentIcon(_ kind: AttachmentKind) -> String {
        switch kind {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .plainText: return "doc.text"
        }
    }

    /// The assistant message bubble: the surface bubble with the message content
    /// and, for completed messages with a valid index, the action buttons —
    /// partial streaming content renders without the action row (new_design.md §5).
    private func assistantBubble(_ message: MessagePresentation, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let content = message.content {
                MarkdownView(content: content)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                    .padding(OmniaTheme.Spacing.md)
                    .background(OmniaTheme.Colors.surface, in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous)
                            .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                    )
                    .shadow(color: OmniaTheme.Shadows.bubble, radius: 8, x: 0, y: 2)
            }
            if message.role == .assistant, index >= 0 {
                assistantActionRow(for: message, index: index)
            }
        }
    }

    /// A saved model that disappeared from its provider's current/fallback
    /// catalog is shown explicitly; Omnia never silently substitutes a model.
    private func unavailableModelBanner(_ selection: ProviderModelSelection) -> some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.warning)
            Text(Localized.modelUnavailable(selection.model.name))
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
            Spacer()
            OmniaButton(
                title: Localized.openProviders,
                systemImage: "globe",
                style: .secondary,
                action: onOpenProviders
            )
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.warningSubtle)
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
        if case .active(let partialContent) = state.streamingCondition, !partialContent.isEmpty {
            AdaptiveMessageBubbleRowLayout(edge: .leading) {
                assistantBubble(MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)), index: -1)
            }
        } else if case .interrupted(let partialContent) = state.streamingCondition {
            VStack(alignment: .leading, spacing: 6) {
                AdaptiveMessageBubbleRowLayout(edge: .leading) {
                    assistantBubble(MessagePresentation(role: .assistant, content: MarkdownContent(markdown: partialContent)), index: -1)
                }
                OmniaButton(
                    title: Localized.retry,
                    systemImage: "arrow.clockwise",
                    style: .secondary,
                    action: onRetry
                )
            }
        }
    }

    /// The streaming state card of the screen: the compact status line that
    /// reflects the current streaming condition above the message history
    /// (new_design.md §5) — the thinking state while a stream has begun but not
    /// yet delivered content, the streaming state while content is streaming,
    /// and the interrupted notice when a stream was cut short.
    @ViewBuilder
    private var streamingStateCard: some View {
        switch state.streamingCondition {
        case .thinking:
            thinkingState
        case .active:
            streamingState
        case .interrupted:
            interruptedState
        case .complete, .none:
            EmptyView()
        }
    }

    /// The streaming state card of the screen: the elevated card with the spark
    /// icon, the state title and line, and the trailing activity indicator,
    /// presented while a stream is forming (COMPONENTS.md, new_design.md §12).
    private func stateCard(
        title: String,
        subtitle: String,
        @ViewBuilder indicator: () -> some View
    ) -> some View {
        HStack(spacing: OmniaTheme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.accent)
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.xs) {
                Text(title)
                    .font(OmniaTheme.Typography.secondary.weight(.semibold))
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(OmniaTheme.Typography.caption)
                    .foregroundStyle(OmniaTheme.Colors.textMuted)
            }
            Spacer()
            indicator()
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.md)
        .background(OmniaTheme.Colors.elevatedSurface, in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous)
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(subtitle)"))
    }

    /// The thinking state: the elevated state card presented while the stream
    /// has begun but the first content delta has not arrived yet (COMPONENTS.md).
    private var thinkingState: some View {
        stateCard(title: Localized.thinking, subtitle: Localized.omniaIsThinking) {
            waveform
        }
    }

    /// The streaming state: the elevated state card presented while the content
    /// deltas are streaming (COMPONENTS.md).
    private var streamingState: some View {
        stateCard(title: Localized.streaming, subtitle: Localized.omniaIsTyping) {
            waveform
        }
    }

    /// The interrupted state: the notice that the response was interrupted,
    /// presented with the preserved partial content of the interruption below
    /// it (ARC-001).
    private var interruptedState: some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "pause.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.warning)
            Text(Localized.responseInterrupted)
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            Spacer()
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
    }

    /// The animated waveform of the thinking and streaming states: three bars
    /// that pulse while a response is forming (new_design.md §5).
    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(OmniaTheme.Colors.accent)
                    .frame(width: 3, height: waveformHeight(index))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: waveformPulse)
            }
        }
        .frame(height: 16)
        .task {
            waveformPulse = true
        }
    }

    /// The height of the waveform bar at the given index, animated by the
    /// waveform pulse so the bars rise and fall in sequence.
    private func waveformHeight(_ index: Int) -> CGFloat {
        let phase = (CGFloat(index) * .pi) / 2
        let wave = (sin(waveformPulse ? phase : phase + .pi / 2) + 1) / 2
        return 6 + wave * 8
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

    /// The error state of the screen: the error card presented above the
    /// composer when the last send failed — the shared error banner with the
    /// error title, the failure message, and the retry action on a red-tinted
    /// surface, the failure presented as it is, never silent (ARC-001,
    /// new_design.md §11).
    private func errorState(_ failure: ConversationScreenState.Failure) -> some View {
        let recovery = state.recoveryAction
        return ErrorBannerView(
            message: FailureCopy.message(for: failure),
            title: Localized.error,
            actionTitle: recovery.map(recoveryTitle) ?? Localized.retry,
            actionSystemImage: recovery.map(recoverySystemImage) ?? "arrow.clockwise",
            onRetry: recovery.map { action in
                { performRecovery(action) }
            }
        )
    }

    private func recoveryTitle(_ action: ConversationScreenState.RecoveryAction) -> String {
        switch action {
        case .retry: return Localized.retry
        case .continueResponse: return Localized.continueResponse
        case .changeModel: return Localized.changeModel
        case .editProvider: return Localized.editProvider
        case .removeAttachments: return Localized.removeAttachments
        case .dismiss: return Localized.dismiss
        }
    }

    private func recoverySystemImage(_ action: ConversationScreenState.RecoveryAction) -> String {
        switch action {
        case .retry: return "arrow.clockwise"
        case .continueResponse: return "play.fill"
        case .changeModel: return "cpu"
        case .editProvider: return "pencil"
        case .removeAttachments: return "paperclip.badge.ellipsis"
        case .dismiss: return "xmark"
        }
    }

    private func performRecovery(_ action: ConversationScreenState.RecoveryAction) {
        switch action {
        case .retry, .continueResponse:
            onRetry()
        case .changeModel:
            isModelSelectionPresented = true
        case .editProvider:
            onOpenProviders()
        case .removeAttachments:
            state.draftAttachments.forEach(onRemoveAttachment)
        case .dismiss:
            onDismissFailure()
        }
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
        static let started = Localized.assistantIsResponding
        static let completed = Localized.responseComplete
        static let interrupted = Localized.responseInterrupted
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
            case .attachment(let error):
                return Localized.attachmentError(error)
            case .unexpected:
                return Localized.unexpectedError
            }
        }

        static func message(for failure: RepositoryError) -> String {
            switch failure {
            case .storageUnavailable:
                return Localized.storageUnavailable
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

/// A full-width message row that proposes at most 80% of its readable width
/// to the bubble group, then places the group's intrinsic result on the role's
/// edge. Short content therefore remains compact while long content wraps at
/// the same proportional cap on every supported window size.
private struct AdaptiveMessageBubbleRowLayout: Layout {
    enum Edge {
        case leading
        case trailing
    }

    private let edge: Edge
    init(edge: Edge) {
        self.edge = edge
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        guard let availableWidth = proposal.width else {
            return subview.sizeThatFits(proposal)
        }
        let bubbleSize = measuredBubble(
            subview,
            availableWidth: availableWidth,
            proposedHeight: proposal.height
        )
        return CGSize(width: availableWidth, height: bubbleSize.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        let bubbleSize = measuredBubble(
            subview,
            availableWidth: bounds.width,
            proposedHeight: proposal.height
        )
        let x: CGFloat
        switch edge {
        case .leading:
            x = bounds.minX
        case .trailing:
            x = bounds.maxX - bubbleSize.width
        }
        subview.place(
            at: CGPoint(x: x, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(bubbleSize)
        )
    }

    private func measuredBubble(
        _ subview: LayoutSubview,
        availableWidth: CGFloat,
        proposedHeight: CGFloat?
    ) -> CGSize {
        let maximumWidth = MessageBubbleWidthPolicy.maximumWidth(for: availableWidth)
        let measured = subview.sizeThatFits(
            ProposedViewSize(width: maximumWidth, height: proposedHeight)
        )
        return CGSize(
            width: MessageBubbleWidthPolicy.resolvedWidth(
                measuredWidth: measured.width,
                availableWidth: availableWidth
            ),
            height: measured.height
        )
    }
}

#endif
