import OmniaApplication

/// Session-lived coordination for conversation generation.
///
/// The coordinator owns the consumer tasks that bridge
/// `ConversationScreenSurface` streams into presentation state. Operations are
/// keyed by `ConversationIdentity`, so navigation only changes which state the
/// shell renders; it never changes the lifetime or ownership of a provider
/// request. The surface and application use case continue to own rendering and
/// persistence respectively (ARC-007, DES-012 §3.3, DES-013 §3.5).
///
/// Every operation also has a monotonically increasing identity. Updates from
/// an operation are accepted only while that exact operation is current for
/// the conversation, which prevents late chunks or termination callbacks from
/// an old task from mutating a replacement operation.
actor ConversationGenerationCoordinator {
    struct OperationIdentity: Equatable, Sendable {
        fileprivate let value: UInt64
    }

    typealias StreamFactory = @Sendable () -> AsyncThrowingStream<ConversationScreenState, any Error>
    typealias StateConsumer = @Sendable (ConversationScreenState) async -> Void
    typealias GenerationOperation = @Sendable (
        @escaping StateConsumer
    ) async throws -> Void
    typealias StateObserver = @MainActor @Sendable (
        ConversationIdentity,
        ConversationScreenState
    ) -> Void

    private enum OperationStatus: Sendable {
        case running
        case cancelling
    }

    private struct Operation: Sendable {
        let identity: OperationIdentity
        let task: Task<Void, Never>
        let observer: StateObserver
        var status: OperationStatus
    }

    private var nextOperationValue: UInt64 = 0
    private var operations: [ConversationIdentity: Operation] = [:]
    private var states: [ConversationIdentity: ConversationScreenState] = [:]

    deinit {
        for operation in operations.values {
            operation.task.cancel()
        }
    }

    /// Returns the latest session state for `conversation`, installing the
    /// repository-backed state supplied by the shell only when the coordinator
    /// has not already observed that conversation.
    func state(
        for conversation: ConversationIdentity,
        loading loadedState: ConversationScreenState
    ) -> ConversationScreenState {
        if let state = states[conversation] {
            return state
        }
        states[conversation] = loadedState
        return loadedState
    }

    /// Whether `conversation` currently owns a running or cancelling
    /// generation operation.
    func isGenerating(_ conversation: ConversationIdentity) -> Bool {
        operations[conversation] != nil
    }

    /// Starts a generation operation unless the same conversation already has
    /// one. Different conversations remain isolated and may progress without a
    /// transient view observer.
    @discardableResult
    func start(
        for conversation: ConversationIdentity,
        initialState: ConversationScreenState,
        makeStream: @escaping StreamFactory,
        observer: @escaping StateObserver
    ) -> OperationIdentity? {
        start(
            for: conversation,
            initialState: initialState,
            perform: { consume in
                for try await state in makeStream() {
                    await consume(state)
                }
            },
            observer: observer
        )
    }

    /// Starts a coordinator-owned structured generation operation unless the
    /// conversation already has one. The operation's whole send, persistence,
    /// and cancellation chain runs in the stored task.
    @discardableResult
    func start(
        for conversation: ConversationIdentity,
        initialState: ConversationScreenState,
        perform: @escaping GenerationOperation,
        observer: @escaping StateObserver
    ) -> OperationIdentity? {
        guard operations[conversation] == nil else { return nil }

        nextOperationValue &+= 1
        let operationIdentity = OperationIdentity(value: nextOperationValue)
        states[conversation] = initialState

        let task = Task { [weak self] in
            await observer(conversation, initialState)
            guard !Task.isCancelled else {
                await self?.workerEnded(for: conversation, operation: operationIdentity)
                return
            }

            do {
                try await perform { [weak self] state in
                    guard let self else { return }
                    _ = await self.receive(
                        state,
                        for: conversation,
                        operation: operationIdentity
                    )
                }
                await self?.workerEnded(for: conversation, operation: operationIdentity)
            } catch is CancellationError {
                await self?.workerEnded(for: conversation, operation: operationIdentity)
            } catch {
                await self?.workerFailed(for: conversation, operation: operationIdentity)
            }
        }

        operations[conversation] = Operation(
            identity: operationIdentity,
            task: task,
            observer: observer,
            status: .running
        )
        return operationIdentity
    }

    /// Explicitly stops the current operation of `conversation`.
    ///
    /// Cancellation is awaited before the operation slot is released. This
    /// lets the Application layer persist its interrupted aggregate before a
    /// replacement request can start, preventing an old cancellation save from
    /// overwriting a newer operation. The last partial content is retained in
    /// the interrupted presentation state.
    @discardableResult
    func cancel(_ conversation: ConversationIdentity) async -> Bool {
        guard var operation = operations[conversation], operation.status == .running else {
            return false
        }

        operation.status = .cancelling
        operations[conversation] = operation
        operation.task.cancel()
        await operation.task.value

        guard let current = operations[conversation],
              current.identity == operation.identity,
              current.status == .cancelling
        else {
            return false
        }

        operations[conversation] = nil
        let interrupted = interruptedState(from: states[conversation])
        states[conversation] = interrupted
        await current.observer(conversation, interrupted)
        return true
    }

    /// Cancels and forgets an operation before its conversation is deleted.
    /// The worker is allowed to persist interruption first; deletion then
    /// remains final and cannot be undone by a late cancellation save.
    func discard(_ conversation: ConversationIdentity) async {
        guard var operation = operations[conversation] else {
            states[conversation] = nil
            return
        }

        operation.status = .cancelling
        operations[conversation] = operation
        operation.task.cancel()
        await operation.task.value

        if operations[conversation]?.identity == operation.identity {
            operations[conversation] = nil
        }
        states[conversation] = nil
    }

    /// Accepts an update only from the current running operation. Terminal
    /// updates release the operation slot before notifying the observer, so a
    /// retry cannot race the old worker's final callback.
    private func receive(
        _ state: ConversationScreenState,
        for conversation: ConversationIdentity,
        operation operationIdentity: OperationIdentity
    ) async -> Bool {
        guard let operation = operations[conversation],
              operation.identity == operationIdentity
        else {
            return false
        }

        if operation.status == .cancelling, !Self.isTerminal(state) {
            return false
        }

        states[conversation] = state
        if Self.isTerminal(state) {
            operations[conversation] = nil
        }
        await operation.observer(conversation, state)
        return true
    }

    /// Releases a normally ended worker. A cancelling worker deliberately
    /// leaves its slot in place for `cancel`/`discard` to finish atomically.
    private func workerEnded(
        for conversation: ConversationIdentity,
        operation operationIdentity: OperationIdentity
    ) {
        guard let operation = operations[conversation],
              operation.identity == operationIdentity,
              operation.status == .running
        else {
            return
        }
        operations[conversation] = nil
    }

    /// Converts an unmapped stream failure into a visible interrupted/failure
    /// state while preserving the latest partial content held by the session.
    private func workerFailed(
        for conversation: ConversationIdentity,
        operation operationIdentity: OperationIdentity
    ) async {
        guard let operation = operations[conversation],
              operation.identity == operationIdentity,
              operation.status == .running
        else {
            return
        }

        operations[conversation] = nil
        let failed = failedState(from: states[conversation])
        states[conversation] = failed
        await operation.observer(conversation, failed)
    }

    private static func isTerminal(_ state: ConversationScreenState) -> Bool {
        if state.failure != nil {
            return true
        }
        switch state.streamingCondition {
        case .complete, .interrupted:
            return true
        case .thinking, .active, .none:
            return false
        }
    }

    private func interruptedState(
        from state: ConversationScreenState?
    ) -> ConversationScreenState {
        let state = state ?? ConversationScreenState(messages: [])
        let partialContent: String
        switch state.streamingCondition {
        case .active(let partial), .interrupted(let partial):
            partialContent = partial
        case .thinking, .complete, .none:
            partialContent = ""
        }
        return ConversationScreenState(
            messages: state.messages,
            draft: state.draft,
            draftAttachments: state.draftAttachments,
            attachmentIssue: state.attachmentIssue,
            streamingCondition: .interrupted(partialContent: partialContent),
            failure: state.failure,
            providerSelection: state.providerSelection
        )
    }

    private func failedState(
        from state: ConversationScreenState?
    ) -> ConversationScreenState {
        let interrupted = interruptedState(from: state)
        return ConversationScreenState(
            messages: interrupted.messages,
            draft: interrupted.draft,
            draftAttachments: interrupted.draftAttachments,
            attachmentIssue: interrupted.attachmentIssue,
            streamingCondition: interrupted.streamingCondition,
            failure: .unexpected,
            providerSelection: interrupted.providerSelection
        )
    }
}
