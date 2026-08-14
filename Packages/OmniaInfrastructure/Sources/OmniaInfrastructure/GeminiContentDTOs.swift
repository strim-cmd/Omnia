import Foundation

/// The Generative Language API request wire model (Gemini, DES-010 §3.5).
///
/// Internal to the package: the request and response models are DTOs confined
/// to OmniaInfrastructure, never part of the public surface (ARC-004,
/// DES-010 §3.5). The model omits `generationConfig` entirely — the adapter
/// sends no generation configuration, mirroring the OpenAI-compatible mapping
/// (DES-010 §3.9.2).
internal struct GenerateContentRequest: Codable, Equatable, Sendable {
    var contents: [GeminiContent]
    var systemInstruction: GeminiSystemInstruction?

    private enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "systemInstruction"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contents, forKey: .contents)
        if let systemInstruction {
            try container.encode(systemInstruction, forKey: .systemInstruction)
        }
    }
}

/// The top-level system instruction of a Generate Content request — the
/// Gemini-translated form of the conversation's system messages (DES-010
/// §3.9.2).
internal struct GeminiSystemInstruction: Codable, Equatable, Sendable {
    var parts: [GeminiPart]
}

/// One turn of the conversation on the Gemini wire, addressed by the provider's
/// own roles (`user` and `model`).
internal struct GeminiContent: Codable, Equatable, Sendable {
    var role: String
    var parts: [GeminiPart]
}

/// One multimodal part of a Gemini content turn: either text or inline image
/// data. Exactly one of the fields is present on the wire.
internal struct GeminiPart: Codable, Equatable, Sendable {
    var text: String?
    var inlineData: GeminiInlineData?

    private enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inlineData"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let text {
            try container.encode(text, forKey: .text)
        }
        if let inlineData {
            try container.encode(inlineData, forKey: .inlineData)
        }
    }
}

/// Base64-encoded inline file data for a multimodal part (DES-010 §3.9.2).
internal struct GeminiInlineData: Codable, Equatable, Sendable {
    var mimeType: String
    var data: String
}

/// The Generate Content response wire model.
internal struct GenerateContentResponse: Codable, Equatable, Sendable {
    var candidates: [GeminiCandidate]?
    var usageMetadata: GeminiUsageMetadata?
}

/// One response candidate; only the first candidate's text is consumed.
internal struct GeminiCandidate: Codable, Equatable, Sendable {
    var index: Int?
    var content: GeminiResponseContent?
    var finishReason: String?
}

/// The content of a response candidate.
internal struct GeminiResponseContent: Codable, Equatable, Sendable {
    var parts: [GeminiPart]?
    var role: String?
}

/// Token usage reported by the endpoint.
internal struct GeminiUsageMetadata: Codable, Equatable, Sendable {
    var promptTokenCount: Int?
    var candidatesTokenCount: Int?
    var totalTokenCount: Int?
}

/// The Gemini model list wire model, used by the availability probe.
internal struct GeminiModelsResponse: Decodable, Sendable {
    var models: [GeminiModelRecord]?
}

/// One record of the Gemini model list; `name` carries the `models/` prefix the
/// API returns, which the client strips before surfacing the catalog.
internal struct GeminiModelRecord: Decodable, Sendable {
    var name: String?
}
