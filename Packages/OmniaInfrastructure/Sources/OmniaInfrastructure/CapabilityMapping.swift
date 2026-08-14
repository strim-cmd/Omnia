import OmniaDomain

/// The translation layer between the Domain capability types and the internal
/// chat-completions DTOs (DES-010 §3.9.2, ARC-004).
///
/// The mapping is confined to the adapter's own translation layer and owns no
/// business logic (ARC-002): it translates the Domain capability requests into
/// the internal wire requests, the internal wire responses back into the
/// Domain capability responses, and the streamed chunks into the Domain
/// streaming updates — without altering the Domain vocabulary (DES-009 §3.11.1)
/// and without letting provider-specific request, response, or chunk shapes
/// cross the package boundary (ARC-004, DES-010 §2.2). It also translates the
/// internal transport failures into the Domain capability errors exactly as
/// the frozen rules declare (DES-010 §3.9.3); raw platform, transport, or
/// provider errors never leak above the adapter.
///
/// The mapping is stateless and deterministic: translation depends only on the
/// values translated (ARC-001, DES-010 §5).
internal enum CapabilityMapping {

    // MARK: Domain requests to wire requests

    /// Maps a text generation request to a non-streaming wire request.
    ///
    /// The prompt becomes a single user `ChatMessage`, `ModelReference.name`
    /// becomes `model`, and `stream` is `false` (DES-010 §3.9.2).
    static func request(from request: TextGenerationRequest) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: request.model.name,
            messages: [ChatMessage(role: "user", content: request.prompt)],
            stream: false,
            temperature: nil,
            maxTokens: nil
        )
    }

    /// Maps a conversation request to a non-streaming wire request.
    ///
    /// The message history becomes the `messages` list (`system`, `user`, and
    /// `assistant` roles in order), `ModelReference.name` becomes `model`, and
    /// `stream` is `false` (DES-010 §3.9.2).
    static func request(from request: ConversationRequest) throws -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: request.model.name,
            messages: try chatMessages(
                from: request.history,
                resolvedAttachments: request.resolvedAttachments
            ),
            stream: false,
            temperature: nil,
            maxTokens: nil
        )
    }

    /// Maps a streaming request to a streaming wire request.
    ///
    /// The message history becomes the `messages` list, `ModelReference.name`
    /// becomes `model`, and `stream` is `true` (DES-010 §3.9.2).
    static func request(from request: StreamingRequest) throws -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: request.model.name,
            messages: try chatMessages(
                from: request.history,
                resolvedAttachments: request.resolvedAttachments
            ),
            stream: true,
            temperature: nil,
            maxTokens: nil
        )
    }

    // MARK: Wire responses to Domain responses

    /// Maps a non-streaming wire response to a text generation response.
    ///
    /// The produced text is the first choice's assistant message content
    /// (DES-010 §3.9.2). A response with no choice or no assistant content is
    /// not a valid capability response (`CapabilityError.invalidResponse`,
    /// DES-009 §3.11.2).
    static func textResponse(from response: ChatCompletionResponse) throws -> TextGenerationResponse {
        TextGenerationResponse(text: try assistantContent(from: response))
    }

    /// Maps a non-streaming wire response to a conversation response.
    ///
    /// The assistant reply is the first choice's assistant message content,
    /// expressed as an assistant `Message` so it appends to the history
    /// (DES-010 §3.9.2, DES-009 §3.11.1). A response with no choice or no
    /// assistant content is not a valid capability response
    /// (`CapabilityError.invalidResponse`, DES-009 §3.11.2).
    static func conversationResponse(from response: ChatCompletionResponse) throws -> ConversationResponse {
        ConversationResponse(message: Message(role: .assistant, content: try assistantContent(from: response)))
    }

    // MARK: Wire chunks to Domain streaming updates

    /// Maps a streamed chunk's content delta to a streaming update.
    ///
    /// A chunk that carries content becomes a `StreamingUpdate.contentDelta`
    /// carrying the request identity (DES-010 §3.9.2, DES-009 §3.11.1); a chunk
    /// whose delta carries no content (for example a role-only or finish-reason
    /// chunk) produces no content delta.
    static func update(
        from chunk: ChatCompletionChunk,
        identity: CapabilityRequestIdentity
    ) -> StreamingUpdate? {
        guard let content = chunk.choices.first?.delta.content else {
            return nil
        }
        return .contentDelta(identity: identity, content: content)
    }

    /// Assembles the completion event's assistant message from the content
    /// accumulated across the streamed deltas (DES-010 §3.9.2, DES-009 §3.11.1).
    static func streamCompletionMessage(from partialContent: String) -> Message {
        Message(role: .assistant, content: partialContent)
    }

    // MARK: Error translation

    /// Translates an internal transport failure into the Domain capability
    /// error the frozen rules declare (DES-010 §3.9.3, DES-009 §3.11.2).
    ///
    /// - `invalidRequest` — the capability request could not be represented on
    ///   the wire — becomes `CapabilityError.invalidRequest`.
    /// - `invalidResponse` — the capability response could not be decoded —
    ///   becomes `CapabilityError.invalidResponse`.
    /// HTTP and network failures retain only their stable, actionable category;
    /// bodies, headers, credentials, and private request content never cross
    /// this boundary.
    static func capabilityError(from error: ProviderTransportError) -> CapabilityError {
        switch error {
        case .invalidRequest:
            return .invalidRequest
        case .invalidResponse:
            return .invalidResponse
        case .httpStatus(let status):
            switch status {
            case 400, 409, 413, 415, 422: return .invalidRequest
            case 401, 403: return .unauthorized
            case 404, 405, 410: return .invalidEndpoint
            case 408: return .timedOut
            case 429: return .rateLimited
            case 500...599: return .serverFailure
            default: return .providerUnavailable
            }
        case .networkFailure:
            return .networkUnavailable
        case .timedOut:
            return .timedOut
        }
    }

    // MARK: Helpers

    private static func chatMessages(
        from history: [Message],
        resolvedAttachments: [ResolvedAttachment]
    ) throws -> [ChatMessage] {
        let resolved = Dictionary(
            resolvedAttachments.map { ($0.attachment.identity, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return try history.map { message in
            guard !message.attachments.isEmpty else {
                return ChatMessage(
                    role: wireRole(for: message.role),
                    content: message.content
                )
            }
            var parts: [ChatContentPart] = []
            if !message.content.isEmpty {
                parts.append(.text(message.content))
            }
            for attachment in message.attachments {
                guard let value = resolved[attachment.identity],
                      value.attachment == attachment
                else {
                    throw CapabilityError.invalidRequest
                }
                switch value.payload {
                case .image(let data, let mediaType):
                    guard attachment.kind == .image,
                          mediaType == attachment.mediaType,
                          mediaType.hasPrefix("image/")
                    else {
                        throw CapabilityError.invalidRequest
                    }
                    parts.append(
                        .imageURL(
                            "data:\(mediaType);base64,\(data.base64EncodedString())"
                        )
                    )
                case .extractedText(let text):
                    guard attachment.kind == .pdf || attachment.kind == .plainText else {
                        throw CapabilityError.invalidRequest
                    }
                    parts.append(
                        .text(
                            "[Attachment: \(safeName(attachment.fileName)) (\(attachment.mediaType))]\n\(text)"
                        )
                    )
                }
            }
            guard !parts.isEmpty else {
                throw CapabilityError.invalidRequest
            }
            return ChatMessage(role: wireRole(for: message.role), parts: parts)
        }
    }

    private static func safeName(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init) ?? "Attachment"
    }

    private static func wireRole(for role: MessageRole) -> String {
        switch role {
        case .system:
            return "system"
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        }
    }

    private static func assistantContent(from response: ChatCompletionResponse) throws -> String {
        guard let content = response.choices.first?.message.content else {
            throw CapabilityError.invalidResponse
        }
        return content
    }
}
