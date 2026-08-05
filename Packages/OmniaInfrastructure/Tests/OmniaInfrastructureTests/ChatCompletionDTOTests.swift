import XCTest
@testable import OmniaInfrastructure

final class ChatCompletionDTOTests: XCTestCase {

    // MARK: - Request encoding

    func testRequest_EncodesWireKeys() throws {
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [
                ChatMessage(role: "system", content: "You are concise."),
                ChatMessage(role: "user", content: "Hello"),
            ],
            stream: false,
            temperature: 0.5,
            maxTokens: 100
        )

        let object = try jsonObject(request)

        XCTAssertEqual(object["model"] as? String, "gpt-4o")
        XCTAssertEqual(object["stream"] as? Bool, false)
        XCTAssertEqual(object["temperature"] as? Double, 0.5)
        XCTAssertEqual(object["max_tokens"] as? Int, 100)
        let messages = object["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2)
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.first?["content"] as? String, "You are concise.")
        XCTAssertNil(object["maxTokens"])
    }

    func testRequest_OmitsOptionalValues() throws {
        let request = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [],
            stream: true,
            temperature: nil,
            maxTokens: nil
        )

        let object = try jsonObject(request)

        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertNil(object["temperature"])
        XCTAssertNil(object["max_tokens"])
    }

    // MARK: - Response decoding

    func testResponse_DecodesWireKeys() throws {
        let json = """
        {
          "id": "chatcmpl-1",
          "model": "gpt-4o",
          "choices": [
            {
              "index": 0,
              "message": { "role": "assistant", "content": "Hello!" },
              "finish_reason": "stop"
            }
          ],
          "usage": { "prompt_tokens": 9, "completion_tokens": 2, "total_tokens": 11 }
        }
        """

        let response = try decode(ChatCompletionResponse.self, from: json)

        XCTAssertEqual(response.id, "chatcmpl-1")
        XCTAssertEqual(response.model, "gpt-4o")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].index, 0)
        XCTAssertEqual(response.choices[0].message.role, "assistant")
        XCTAssertEqual(response.choices[0].message.content, "Hello!")
        XCTAssertEqual(response.choices[0].finishReason, "stop")
        XCTAssertEqual(response.usage?.promptTokens, 9)
        XCTAssertEqual(response.usage?.completionTokens, 2)
        XCTAssertEqual(response.usage?.totalTokens, 11)
    }

    func testResponse_DecodesMissingUsageAndOptionalMessageContent() throws {
        let json = """
        {
          "id": "chatcmpl-2",
          "model": "gpt-4o",
          "choices": [
            { "index": 0, "message": { "role": "assistant" } }
          ]
        }
        """

        let response = try decode(ChatCompletionResponse.self, from: json)

        XCTAssertNil(response.usage)
        XCTAssertNil(response.choices[0].message.content)
        XCTAssertNil(response.choices[0].finishReason)
    }

    // MARK: - Chunk decoding

    func testChunk_DecodesWireKeys() throws {
        let json = """
        {
          "id": "chatcmpl-3",
          "model": "gpt-4o",
          "choices": [
            {
              "index": 0,
              "delta": { "role": "assistant", "content": "Hello" },
              "finish_reason": null
            }
          ]
        }
        """

        let chunk = try decode(ChatCompletionChunk.self, from: json)

        XCTAssertEqual(chunk.id, "chatcmpl-3")
        XCTAssertEqual(chunk.model, "gpt-4o")
        XCTAssertEqual(chunk.choices[0].index, 0)
        XCTAssertEqual(chunk.choices[0].delta.role, "assistant")
        XCTAssertEqual(chunk.choices[0].delta.content, "Hello")
        XCTAssertNil(chunk.choices[0].finishReason)
    }

    func testChunk_DecodesEmptyDelta() throws {
        let json = """
        {
          "id": "chatcmpl-4",
          "model": "gpt-4o",
          "choices": [
            { "index": 0, "delta": { "finish_reason": "stop" } }
          ]
        }
        """

        let chunk = try decode(ChatCompletionChunk.self, from: json)

        XCTAssertNil(chunk.choices[0].delta.role)
        XCTAssertNil(chunk.choices[0].delta.content)
    }

    // MARK: - Helpers

    private func jsonObject(_ request: ChatCompletionRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Request should encode as a JSON object"
        )
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
