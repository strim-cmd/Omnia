import OmniaDomain

/// The translation layer between the Domain capability types and the internal
/// Gemini wire DTOs (DES-010 §3.9.2, ARC-004).
///
/// The mapping mirrors `CapabilityMapping` for the Generative Language API: it
/// translates the Domain capability requests into the internal wire requests,
/// the internal wire responses back into the Domain capability responses, and
/// the streamed events into the Domain streaming updates — without altering the
/// Domain vocabulary (DES-009 §3.11.1) and without letting provider-specific
/// request, response, or event shapes cross the package boundary (ARC-004,
/// DES-010 §2.2). Transport failures are translated into the Domain capability
/// errors by the frozen rule of `CapabilityMapping.capabilityError(from:)`
/// (DES-010 §3.9.3).
///
/// The Gemini translation differs from the OpenAI-compatible one only in wire
/// shape: the conversation's system messages become the top-level
/// `systemInstruction` (Gemini has no system role in `contents`), user and
/// assistant messages become `user`/`model` contents, and image attachments
/// become base64 `inlineData` parts instead of data URLs.
///
/// The mapping is stateless and deterministic: translation depends only on the
/// values translated (ARC-001, DES-010 §5).
internal enum GeminiMapping {

    // MARK: Domain requests to wire requests

    /// Maps a text generation request to a Generate Content request.
    ///
    /// The prompt becomes a single user `GeminiContent` with one text part
    /// (DES-010 §3.9.2).
    static func request(from request: TextGenerationRequest) -> GenerateContentRequest {
        GenerateContentRequest(
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: request.prompt)]),
            ],
            systemInstruction: nil
        )
    }

    /// Maps a conversation request to a Generate Content request.
    ///
    /// The message history becomes the `contents` list and the system
    /// instruction: system messages become the top-level `systemInstruction`
    /// (concatenated in order), and user and assistant messages become
    /// `user`/`model` contents in order (DES-010 §3.9.2).
    static func request(from request: ConversationRequest) throws -> GenerateContentRequest {
        try request(
            from: request.history,
            resolvedAttachments: request.resolvedAttachments
        )
    }

    /// Maps a streaming request to a Generate Content request — the same wire
    /// request as the conversation mapping; the streaming flag lives in the
    /// URL action, not in the body (DES-010 §3.9.2).
    static func request(from request: StreamingRequest) throws -> GenerateContentRequest {
        try request(
            from: request.history,
            resolvedAttachments: request.resolvedAttachments
        )
    }

    // MARK: Wire responses to Domain responses

    /// Maps a non-streaming wire response to a text generation response.
    ///
    /// The produced text is the first candidate's joined text parts. A response
    /// with no candidate or no text is not a valid capability response
    /// (`CapabilityError.invalidResponse`, DES-009 §3.11.2).
    static func textResponse(from response: GenerateContentResponse) throws -> TextGenerationResponse {
        TextGenerationResponse(text: try assistantText(from: response))
    }

    /// Maps a non-streaming wire response to a conversation response.
    ///
    /// The assistant reply is the first candidate's joined text parts, expressed
    /// as an assistant `Message` so it appends to the history (DES-010 §3.9.2,
    /// DES-009 §3.11.1). A response with no candidate or no text is not a valid
    /// capability response (`CapabilityError.invalidResponse`, DES-009 §3.11.2).
    static func conversationResponse(from response: GenerateContentResponse) throws -> ConversationResponse {
        ConversationResponse(message: Message(role: .assistant, content: try assistantText(from: response)))
    }

    // MARK: Wire events to Domain streaming updates

    /// Maps a streamed event's text to a streaming update.
    ///
    /// An event whose first candidate carries text becomes a
    /// `StreamingUpdate.contentDelta` carrying the request identity (DES-010
    /// §3.9.2, DES-009 §3.11.1); an event with no candidate text produces no
    /// content delta.
    static func update(
        from response: GenerateContentResponse,
        identity: CapabilityRequestIdentity
    ) -> StreamingUpdate? {
        let text = candidateText(from: response)
        guard !text.isEmpty else {
            return nil
        }
        return .contentDelta(identity: identity, content: text)
    }

    /// Assembles the completion event's assistant message from the content
    /// accumulated across the streamed deltas (DES-010 §3.9.2, DES-009 §3.11.1).
    static func streamCompletionMessage(from partialContent: String) -> Message {
        Message(role: .assistant, content: partialContent)
    }

    // MARK: Error translation

    /// Translates an internal transport failure into the Domain capability
    /// error the frozen rules declare (DES-010 §3.9.3, DES-009 §3.11.2) — the
    /// same rule the OpenAI-compatible mapping applies.
    static func capabilityError(from error: ProviderTransportError) -> CapabilityError {
        CapabilityMapping.capabilityError(from: error)
    }

    // MARK: Helpers

    private static func request(
        from history: [Message],
        resolvedAttachments: [ResolvedAttachment]
    ) throws -> GenerateContentRequest {
        let resolved = Dictionary(
            resolvedAttachments.map { ($0.attachment.identity, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var contents: [GeminiContent] = []
        var systemParts: [GeminiPart] = []
        for message in history {
            switch message.role {
            case .system:
                if !message.content.isEmpty {
                    systemParts.append(GeminiPart(text: message.content))
                }
            case .user, .assistant:
                contents.append(
                    GeminiContent(
                        role: message.role == .assistant ? "model" : "user",
                        parts: try parts(for: message, resolved: resolved)
                    )
                )
            }
        }
        return GenerateContentRequest(
            contents: contents,
            systemInstruction: systemParts.isEmpty ? nil : GeminiSystemInstruction(parts: systemParts)
        )
    }

    private static func parts(
        for message: Message,
        resolved: [AttachmentIdentity: ResolvedAttachment]
    ) throws -> [GeminiPart] {
        guard !message.attachments.isEmpty else {
            return [GeminiPart(text: message.content)]
        }
        var parts: [GeminiPart] = []
        if !message.content.isEmpty {
            parts.append(GeminiPart(text: message.content))
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
                    GeminiPart(
                        inlineData: GeminiInlineData(
                            mimeType: mediaType,
                            data: data.base64EncodedString()
                        )
                    )
                )
            case .extractedText(let text):
                guard attachment.kind == .pdf || attachment.kind == .plainText else {
                    throw CapabilityError.invalidRequest
                }
                parts.append(
                    GeminiPart(
                        text: "[Attachment: \(safeName(attachment.fileName)) (\(attachment.mediaType))]\n\(text)"
                    )
                )
            }
        }
        guard !parts.isEmpty else {
            throw CapabilityError.invalidRequest
        }
        return parts
    }

    private static func safeName(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init) ?? "Attachment"
    }

    private static func candidateText(from response: GenerateContentResponse) -> String {
        guard let content = response.candidates?.first?.content, let parts = content.parts else {
            return ""
        }
        return parts.compactMap(\.text).joined()
    }

    private static func assistantText(from response: GenerateContentResponse) throws -> String {
        let text = candidateText(from: response)
        guard !text.isEmpty else {
            throw CapabilityError.invalidResponse
        }
        return text
    }
}
