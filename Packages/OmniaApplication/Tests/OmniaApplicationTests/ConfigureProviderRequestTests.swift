import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaApplication

private let secretValue = "sk-provider-secret-that-must-never-leak"

final class ConfigureProviderRequestTests: XCTestCase {

    private func request(
        displayName: String = "Example Provider",
        capabilities: ProviderCapabilities = ProviderCapabilities(
            capabilities: [.textGeneration, .conversation]
        ),
        limits: ProviderLimits = ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion = SemanticVersion(major: 1, minor: 0, patch: 0),
        credential: Credential = Credential(secret: secretValue)
    ) -> ConfigureProviderRequest {
        ConfigureProviderRequest(
            displayName: displayName,
            capabilities: capabilities,
            limits: limits,
            version: version,
            credential: credential
        )
    }

    // MARK: Creation

    func testCreation_ExposesAllFields() {
        let request = request()
        XCTAssertEqual(request.displayName, "Example Provider")
        XCTAssertEqual(
            request.capabilities,
            ProviderCapabilities(capabilities: [.textGeneration, .conversation])
        )
        XCTAssertEqual(request.limits, ProviderLimits(maxRequestsPerMinute: 60))
        XCTAssertEqual(request.version, SemanticVersion(major: 1, minor: 0, patch: 0))
        request.credential.withValue { XCTAssertEqual($0, secretValue) }
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        XCTAssertEqual(request(), request())
    }

    func testEquality_DifferentDisplayNameIsNotEqual() {
        XCTAssertNotEqual(request(displayName: "A"), request(displayName: "B"))
    }

    func testEquality_DifferentCapabilitiesIsNotEqual() {
        let one = request(capabilities: ProviderCapabilities(capabilities: [.textGeneration]))
        let two = request(capabilities: ProviderCapabilities(capabilities: [.conversation]))
        XCTAssertNotEqual(one, two)
    }

    func testEquality_DifferentLimitsIsNotEqual() {
        let one = request(limits: ProviderLimits(maxRequestsPerMinute: 60))
        let two = request(limits: ProviderLimits(maxRequestsPerMinute: 120))
        XCTAssertNotEqual(one, two)
    }

    func testEquality_DifferentVersionIsNotEqual() {
        let one = request(version: SemanticVersion(major: 1, minor: 0, patch: 0))
        let two = request(version: SemanticVersion(major: 2, minor: 0, patch: 0))
        XCTAssertNotEqual(one, two)
    }

    func testEquality_DifferentCredentialIsNotEqual() {
        let one = request(credential: Credential(secret: secretValue))
        let two = request(credential: Credential(secret: "sk-different-secret"))
        XCTAssertNotEqual(one, two)
    }

    // MARK: Immutability

    func testImmutability_ValuesNeverChangeAfterCreation() {
        let request = request()
        XCTAssertEqual(request.displayName, "Example Provider")
        XCTAssertEqual(request.version, SemanticVersion(major: 1, minor: 0, patch: 0))
        request.credential.withValue { XCTAssertEqual($0, secretValue) }
    }

    // MARK: Credential redaction

    func testDescription_NeverRevealsTheSecret() {
        let request = request()
        XCTAssertFalse(request.description.contains(secretValue))
        XCTAssertTrue(request.description.contains("<redacted>"))
    }

    func testDebugDescription_NeverRevealsTheSecret() {
        let request = request()
        XCTAssertFalse(request.debugDescription.contains(secretValue))
        XCTAssertEqual(String(reflecting: request), request.description)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let request = request()
        let returned = await Task.detached {
            request
        }.value
        XCTAssertEqual(returned, request)
    }
}
