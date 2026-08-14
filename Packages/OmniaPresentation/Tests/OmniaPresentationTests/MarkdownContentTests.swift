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
                .codeBlock(content: "code", language: nil),
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
            [.codeBlock(content: "let a = 1\n\n  indented\n", language: nil)]
        )
    }

    func testOpeningFence_LanguageIdentifierIsNotPartOfTheContent() {
        let content = MarkdownContent(markdown: "```swift\nlet x = 1\n```")
        XCTAssertEqual(
            content.segments,
            [.codeBlock(content: "let x = 1", language: "swift")]
        )
    }

    func testUnclosedFence_ExtendsToTheEnd() {
        let content = MarkdownContent(markdown: "```\nlet x = 1\nnot closed")
        XCTAssertEqual(
            content.segments,
            [.codeBlock(content: "let x = 1\nnot closed", language: nil)]
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
        XCTAssertEqual(content.segments, [.codeBlock(content: "code", language: nil)])
    }

    func testConsecutiveCodeBlocks_AreOrdered() {
        let content = MarkdownContent(
            markdown: "```\na\n```\n```\nb\n```"
        )
        XCTAssertEqual(
            content.segments,
            [
                .codeBlock(content: "a", language: nil),
                .codeBlock(content: "b", language: nil),
            ]
        )
    }

    func testSemanticBlocks_CoverHeadingsListsQuotesRulesAndParagraphs() {
        let content = MarkdownContent(
            markdown: "# Heading\n\nParagraph with **bold**, *emphasis*, `inline`, and [link](https://example.com).\n\n- First\n2. Second\n> Quote\n---"
        )

        XCTAssertEqual(content.blocks, [
            .heading(level: 1, content: "Heading"),
            .paragraph("Paragraph with **bold**, *emphasis*, `inline`, and [link](https://example.com)."),
            .unorderedListItem("First"),
            .orderedListItem(number: 2, content: "Second"),
            .blockQuote("Quote"),
            .horizontalRule,
        ])
    }

    func testInvalidAndIncompleteStreamingMarkdownDegradesDeterministically() {
        let markdown = "## Heading\nParagraph with **unfinished\n```swift\nlet value = 1"

        let content = MarkdownContent(markdown: markdown)

        XCTAssertEqual(content.blocks, [
            .heading(level: 2, content: "Heading"),
            .paragraph("Paragraph with **unfinished"),
            .codeBlock(content: "let value = 1", language: "swift"),
        ])
        XCTAssertEqual(content, MarkdownContent(markdown: markdown))
    }

    func testLongCodeRemainsExactlyCopyable() {
        let code = (0..<500).map { "let value\($0) = \($0)" }.joined(separator: "\n")
        let content = MarkdownContent(markdown: "```swift\n\(code)\n```")

        XCTAssertEqual(content.copyableCodeBlocks, [code])
    }

    func testLanguageLabelIsBoundedAndContainsOnlySafeCharacters() {
        let content = MarkdownContent(markdown: "```swift<script>alert\ncode\n```")

        XCTAssertEqual(
            content.blocks,
            [.codeBlock(content: "code", language: "swiftscriptalert")]
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
        let a = MarkdownContent(segments: [.text("Hi"), .codeBlock(content: "c", language: nil)])
        let b = MarkdownContent(segments: [.text("Hi"), .codeBlock(content: "c", language: nil)])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentSegmentsAreNotEqual() {
        let a = MarkdownContent(segments: [.text("Hi")])
        let b = MarkdownContent(segments: [.codeBlock(content: "Hi", language: nil)])
        XCTAssertNotEqual(a, b)
    }
}
