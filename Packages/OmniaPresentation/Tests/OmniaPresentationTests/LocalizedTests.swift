import XCTest
@testable import OmniaPresentation

final class LocalizedTests: XCTestCase {
    func testVisibleConversationCopyResolvesFromPresentationBundle() {
        let resolvedValues = [
            ("message_placeholder", Localized.messagePlaceholder),
            ("new_conversation", Localized.newConversation),
            ("conversations", Localized.conversations),
            ("delete", Localized.delete),
            ("delete_conversation", Localized.deleteConversation),
            ("attachment", Localized.attachment),
            ("send", Localized.send),
            ("stop", Localized.stop),
        ]

        for (key, value) in resolvedValues {
            XCTAssertNotEqual(value, key, "Localization key leaked into visible UI: \(key)")
        }

        XCTAssertEqual(Localized.messagePlaceholder, "Message Omnia...")
        XCTAssertEqual(Localized.delete, "Delete")
    }

    func testFormattedCopyUsesPresentationBundle() {
        XCTAssertEqual(
            Localized.providerSelectionCurrent("Example"),
            "Provider selection. Current: Example"
        )
        XCTAssertEqual(
            Localized.providerUnavailable("Example"),
            "Example is not available. Messages will use the automatic selection."
        )
    }
}
