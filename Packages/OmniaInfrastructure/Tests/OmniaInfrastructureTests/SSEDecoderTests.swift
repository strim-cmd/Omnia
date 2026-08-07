import XCTest
@testable import OmniaInfrastructure

final class SSEDecoderTests: XCTestCase {

    private func decoder() -> SSEDecoder {
        SSEDecoder()
    }

    func testAppend_EmitsASingleEvent() {
        var decoder = decoder()
        let events = decoder.append(Data("data: hello\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "hello")])
    }

    func testAppend_EmitsMultipleEventsInOneChunk() {
        var decoder = decoder()
        let events = decoder.append(Data("data: one\n\ndata: two\n\n".utf8))

        XCTAssertEqual(
            events,
            [
                SSEEvent(event: nil, data: "one"),
                SSEEvent(event: nil, data: "two"),
            ]
        )
    }

    func testAppend_EventSplitAcrossChunksIsEmittedWhenComplete() {
        var decoder = decoder()
        XCTAssertTrue(decoder.append(Data("data: hel".utf8)).isEmpty)
        let events = decoder.append(Data("lo\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "hello")])
    }

    func testAppend_UTF8ContentSurvivesByteByByteDelivery() {
        var decoder = decoder()
        let expected = "Привет, мир! 😊"
        var events: [SSEEvent] = []
        for byte in Data("data: \(expected)\n\n".utf8) {
            events.append(contentsOf: decoder.append(Data([byte])))
        }

        XCTAssertEqual(events, [SSEEvent(event: nil, data: expected)])
    }

    func testAppend_MultiByteUTF8CharacterSplitAcrossChunks() {
        var decoder = decoder()
        let expected = "Привет"
        let payload = Data("data: \(expected)\n\n".utf8)
        var events: [SSEEvent] = []
        var index = 0
        while index < payload.count {
            let end = min(index + 3, payload.count)
            events.append(contentsOf: decoder.append(payload.subdata(in: index..<end)))
            index = end
        }

        XCTAssertEqual(events, [SSEEvent(event: nil, data: expected)])
    }

    func testAppend_PartialEventIsHeldUntilTheBlankLine() {
        var decoder = decoder()
        XCTAssertTrue(decoder.append(Data("data: pending\n".utf8)).isEmpty)
        let events = decoder.append(Data("\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "pending")])
    }

    func testAppend_HandlesCarriageReturnLineEndings() {
        var decoder = decoder()
        let events = decoder.append(Data("data: crlf\r\n\r\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "crlf")])
    }

    func testAppend_JoinsMultilineDataWithNewlines() {
        var decoder = decoder()
        let events = decoder.append(Data("data: first\ndata: second\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "first\nsecond")])
    }

    func testAppend_CarriesTheEventType() {
        var decoder = decoder()
        let events = decoder.append(Data("event: error\ndata: boom\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: "error", data: "boom")])
    }

    func testAppend_IgnoresCommentLines() {
        var decoder = decoder()
        let events = decoder.append(Data(": keep-alive\ndata: value\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "value")])
    }

    func testAppend_IgnoresUnrecognizedFields() {
        var decoder = decoder()
        let events = decoder.append(Data("id: 1\ndata: value\n\n".utf8))

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "value")])
    }

    func testFinish_FlushesAEventWithoutATrailingNewline() {
        var decoder = decoder()
        XCTAssertTrue(decoder.append(Data("data: trailing".utf8)).isEmpty)
        let events = decoder.finish()

        XCTAssertEqual(events, [SSEEvent(event: nil, data: "trailing")])
    }

    func testFinish_FlushesUTF8ContentWithoutATrailingNewline() {
        var decoder = decoder()
        let expected = "Привет, мир!"
        XCTAssertTrue(decoder.append(Data("data: \(expected)".utf8)).isEmpty)
        let events = decoder.finish()

        XCTAssertEqual(events, [SSEEvent(event: nil, data: expected)])
    }

    func testFinish_ReturnsNothingWhenNothingWasBuffered() {
        var decoder = decoder()
        XCTAssertTrue(decoder.finish().isEmpty)
    }

    func testFinish_AfterACompleteEventReturnsNothing() {
        var decoder = decoder()
        let first = decoder.append(Data("data: done\n\n".utf8))
        XCTAssertEqual(first, [SSEEvent(event: nil, data: "done")])
        XCTAssertTrue(decoder.finish().isEmpty)
    }
}
