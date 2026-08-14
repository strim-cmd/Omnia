import Foundation

/// The chat-completions request wire model (DES-010 §3.5).
///
/// Internal to the package: the request and response models are DTOs confined
/// to OmniaInfrastructure, never part of the public surface (ARC-004,
/// DES-010 §3.5).
internal struct ChatCompletionRequest: Codable, Equatable, Sendable {
    var model: String
    var messages: [ChatMessage]
    var stream: Bool
    var temperature: Double?
    var maxTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

/// A single chat message on the wire (DES-010 §3.5).
///
/// The role is the provider's wire role (`system`, `user`, or `assistant`);
/// the wire form is independent of the Domain conversation model.
internal struct ChatMessage: Codable, Equatable, Sendable {
    var role: String
    var content: ChatMessageContent

    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    init(role: String, parts: [ChatContentPart]) {
        self.role = role
        self.content = .parts(parts)
    }
}

/// Chat-completions accepts either a legacy string or typed multimodal parts.
internal enum ChatMessageContent: Codable, Equatable, Sendable {
    case text(String)
    case parts([ChatContentPart])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .parts(try container.decode([ChatContentPart].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

internal enum ChatContentPart: Codable, Equatable, Sendable {
    case text(String)
    case imageURL(String)

    private enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    private struct ImageURLValue: Codable, Equatable, Sendable {
        let url: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image_url":
            self = .imageURL(
                try container.decode(ImageURLValue.self, forKey: .imageURL).url
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported chat content part."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageURLValue(url: url), forKey: .imageURL)
        }
    }
}

/// The chat-completions response wire model (DES-010 §3.5).
internal struct ChatCompletionResponse: Codable, Equatable, Sendable {
    var id: String
    var model: String
    var choices: [ChatCompletionChoice]
    var usage: ChatCompletionUsage?
}

/// One response choice (DES-010 §3.5).
internal struct ChatCompletionChoice: Codable, Equatable, Sendable {
    var index: Int
    var message: ChatCompletionResponseMessage
    var finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

/// The assistant message inside a response choice (DES-010 §3.5).
///
/// The content is optional because some providers return assistant messages
/// without text (for example, tool or reasoning roles).
internal struct ChatCompletionResponseMessage: Codable, Equatable, Sendable {
    var role: String
    var content: String?
}

/// Token usage reported by the endpoint (DES-010 §3.5).
internal struct ChatCompletionUsage: Codable, Equatable, Sendable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// One streamed chat-completions chunk (DES-010 §3.5).
internal struct ChatCompletionChunk: Codable, Equatable, Sendable {
    var id: String
    var model: String
    var choices: [ChatCompletionChunkChoice]
}

/// One streamed choice (DES-010 §3.5).
internal struct ChatCompletionChunkChoice: Codable, Equatable, Sendable {
    var index: Int
    var delta: ChatCompletionChunkDelta
    var finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

/// The incremental content delta of a streamed choice (DES-010 §3.5).
internal struct ChatCompletionChunkDelta: Codable, Equatable, Sendable {
    var role: String?
    var content: String?
}
