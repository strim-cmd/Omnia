import Foundation
import XCTest
@testable import OmniaDomain

private let secretValue = "sk-secret-value-that-must-never-leak"

final class CredentialTests: XCTestCase {

    func testCreation_HoldsTheGivenSecret() {
        let credential = Credential(secret: secretValue)
        credential.withValue { XCTAssertEqual($0, secretValue) }
    }

    func testWithValue_ScopesAccessToTheClosure() {
        let credential = Credential(secret: secretValue)
        let captured = credential.withValue { $0.count }
        XCTAssertEqual(captured, secretValue.count)
    }

    func testEquality_SameSecretIsEqual() {
        XCTAssertEqual(Credential(secret: secretValue), Credential(secret: secretValue))
    }

    func testEquality_DifferentSecretIsNotEqual() {
        XCTAssertNotEqual(Credential(secret: secretValue), Credential(secret: "other-secret"))
    }

    func testDescription_NeverRevealsTheSecret() {
        let credential = Credential(secret: secretValue)
        XCTAssertFalse(credential.description.contains(secretValue))
        XCTAssertEqual(credential.description, "Credential(<redacted>)")
    }

    func testDebugDescription_NeverRevealsTheSecret() {
        let credential = Credential(secret: secretValue)
        XCTAssertFalse(credential.debugDescription.contains(secretValue))
        XCTAssertEqual(String(reflecting: credential), "Credential(<redacted>)")
    }

    func testSendability_ShareCredentialAcrossConcurrencyDomain() async {
        let credential = Credential(secret: secretValue)
        let length: Int = await Task.detached {
            credential.withValue { $0.count }
        }.value
        XCTAssertEqual(length, secretValue.count)
    }
}
