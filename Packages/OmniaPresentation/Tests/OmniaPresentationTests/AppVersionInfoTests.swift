import XCTest
@testable import OmniaPresentation

final class AppVersionInfoTests: XCTestCase {
    func testResolvingBundleMetadataReturnsExactVersionAndBuild() {
        let info = AppVersionInfo.resolving(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
            ]
        )

        XCTAssertEqual(info, AppVersionInfo(version: "1.0.0", build: "1"))
        XCTAssertEqual(info?.localizedDescription, "Version 1.0.0 (Build 1)")
    }

    func testResolvingBundleMetadataRejectsMissingOrEmptyValues() {
        XCTAssertNil(AppVersionInfo.resolving(infoDictionary: nil))
        XCTAssertNil(
            AppVersionInfo.resolving(
                infoDictionary: ["CFBundleShortVersionString": "1.0.0"]
            )
        )
        XCTAssertNil(
            AppVersionInfo.resolving(
                infoDictionary: [
                    "CFBundleShortVersionString": " ",
                    "CFBundleVersion": "1",
                ]
            )
        )
    }
}
