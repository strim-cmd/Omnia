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
            ("app_version_build_format", Localized.appVersionBuild(version: "1.0.0", build: "1")),
            ("send", Localized.send),
            ("stop", Localized.stop),
            ("add_first_provider", Localized.addFirstProvider),
            ("clear_data", Localized.clearData),
            ("clear_data_confirmation", Localized.clearDataConfirmation),
            ("clear_data_scope", Localized.clearDataScope),
            ("manage_providers", Localized.manageProviders),
            ("api_kind", Localized.apiKind),
            ("api_kind_openai", Localized.apiKindOpenAICompatible),
            ("api_kind_gemini", Localized.apiKindGemini),
        ]

        for (key, value) in resolvedValues {
            XCTAssertNotEqual(value, key, "Localization key leaked into visible UI: \(key)")
        }

        XCTAssertEqual(Localized.messagePlaceholder, "Message Omnia...")
        XCTAssertEqual(Localized.delete, "Delete")
        XCTAssertEqual(Localized.apiKind, "API Type")
        XCTAssertEqual(Localized.apiKindOpenAICompatible, "OpenAI-compatible")
        XCTAssertEqual(Localized.apiKindGemini, "Gemini")
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
        XCTAssertEqual(
            Localized.appVersionBuild(version: "1.0.0", build: "1"),
            "Version 1.0.0 (Build 1)"
        )
    }
}
