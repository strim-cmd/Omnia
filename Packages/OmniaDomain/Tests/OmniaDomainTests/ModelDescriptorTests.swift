import XCTest
@testable import OmniaDomain

final class ModelDescriptorTests: XCTestCase {
    func testCapabilities_DefaultToUnknownAndNeverGuessMultimodalSupport() {
        let profile = ModelCapabilityProfile()

        XCTAssertEqual(profile.support(for: .vision), .unknown)
        XCTAssertEqual(profile.support(for: .documentInput), .unknown)
        XCTAssertEqual(profile.support(for: .streaming), .unknown)
    }

    func testExplicitUnsupportedWinsOverSupported() {
        let profile = ModelCapabilityProfile(
            supported: [.vision, .streaming],
            unsupported: [.vision]
        )

        XCTAssertEqual(profile.support(for: .vision), .unsupported)
        XCTAssertEqual(profile.support(for: .streaming), .supported)
    }

    func testProviderScopedSelectionDistinguishesSameModelAcrossProviders() {
        let model = ModelReference(name: "shared")
        let first = ProviderModelSelection(provider: ProviderIdentity(), model: model)
        let second = ProviderModelSelection(provider: ProviderIdentity(), model: model)

        XCTAssertNotEqual(first, second)
    }

    func testReplacingCapabilityIsExplicitImmutableAndReversibleToUnknown() {
        let original = ModelCapabilityProfile(supported: [.streaming])
        let supported = original.replacing(.supported, for: .vision)
        let unsupported = supported.replacing(.unsupported, for: .vision)
        let unknown = unsupported.replacing(.unknown, for: .vision)

        XCTAssertEqual(original.support(for: .vision), .unknown)
        XCTAssertEqual(supported.support(for: .vision), .supported)
        XCTAssertEqual(unsupported.support(for: .vision), .unsupported)
        XCTAssertEqual(unknown.support(for: .vision), .unknown)
        XCTAssertEqual(unknown.support(for: .streaming), .supported)
    }
}
