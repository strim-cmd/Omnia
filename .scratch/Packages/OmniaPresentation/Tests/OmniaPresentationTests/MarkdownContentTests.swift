import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class MarkdownContentTests: XCTestCase {

    // MARK: Segmentation

    func testPlainText_IsASingleTextSegment() {
        let content = MarkdownContent(markdown: "Hello world")
        XCTAssertEqual(content.segments, [.text("Hello world")])
    }

    func testMultiLineText_IsASingleTextSegment() {
        let content = MarkdownContent(markdown: "Line one\nLine two")
        XCTAssertEqual(content.segments, [.text("Line one\nLine two")])
    }

    func testFencedCodeBlock_SegmentsTextAndCode() {
        let content = MarkdownContent(markdown: "Before\n```\ncode\n```\nAfter")
        XCTAssertEqual(
            content.segments,
            [
                .text("Before"),
                .codeBlock(content: "code"),
                .text("After"),
            ]
        )
    }

    func testCodeBlock_WhitespaceIsPreserved() {
        let content = MarkdownContent(
            markdown: "```\nlet a = 1\n\n  indented\n\n```\n"
        )
        XCTAssertEqual(
            content.segments,
            [.codeBlock(content: "let a = 1\n\n  indented\n")]
        )
    }

    func testOpeningFence_LanguageIdentifierIsNotPartOfTheContent() {
        let content = MarkdownContent(markdown: "```swift\nlet x = 1\n```")
        XCTAssertEqual(content.segments, [.codeBlock(content: "let x = 1")])
    }

    func testUnclosedFence_ExtendsToTheEnd() {
        let content = MarkdownContent(markdown: "```\nlet x = 1\nnot closed")
        XCTAssertEqual(
            content.segments,
            [.codeBlock(content: "let x = 1\nnot closed")]
        )
    }

    func testInlineBackticks_AreNotFences() {
        let content = MarkdownContent(markdown: "Use `code` inline")
        XCTAssertEqual(content.segments, [.text("Use `code` inline")])
    }

    func testSingleBacktick_IsNotAFence() {
        let content = MarkdownContent(markdown: "` not a fence")
        XCTAssertEqual(content.segments, [.text("` not a fence")])
    }

    func testEmptyContent_HasNoSegments() {
        let content = MarkdownContent(markdown: "")
        XCTAssertEqual(content.segments, [])
    }

    func testEmptyTextRuns_AreNotEmitted() {
        let content = MarkdownContent(markdown: "\n```\ncode\n```\n")
        XCTAssertEqual(content.segments, [.codeBlock(content: "code")])
    }

    func testConsecutiveCodeBlocks_AreOrdered() {
        let content = MarkdownContent(
            markdown: "```\na\n```\n```\nb\n```"
        )
        XCTAssertEqual(
            content.segments,
            [
                .codeBlock(content: "a"),
                .codeBlock(content: "b"),
            ]
        )
    }

    // MARK: Determinism

    func testSegmentation_IsDeterministic() {
        let markdown = "Intro\n```\ncode\n```\nOutro"
        XCTAssertEqual(
            MarkdownContent(markdown: markdown).segments,
            MarkdownContent(markdown: markdown).segments
        )
    }

    // MARK: Equality

    func testEquality_SameSegmentsAreEqual() {
        let a = MarkdownContent(segments: [.text("Hi"), .codeBlock(content: "c")])
        let b = MarkdownContent(segments: [.text("Hi"), .codeBlock(content: "c")])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentSegmentsAreNotEqual() {
        let a = MarkdownContent(segments: [.text("Hi")])
        let b = MarkdownContent(segments: [.codeBlock(content: "Hi")])
        XCTAssertNotEqual(a, b)
    }
}
