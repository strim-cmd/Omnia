import OmniaDomain
import XCTest
@testable import OmniaApplication

final class ApplicationValidationErrorTests: XCTestCase {

    // MARK: Reason carrying

    func testInvalid_CarriesTheReason() {
        let error = ApplicationValidationError.invalid(reason: "message is empty")
        guard case .invalid(let reason) = error else {
            return XCTFail("Expected an invalid-input error")
        }
        XCTAssertEqual(reason, "message is empty")
    }

    func testInvalid_EmptyReasonIsPreserved() {
        XCTAssertEqual(
            ApplicationValidationError.invalid(reason: ""),
            ApplicationValidationError.invalid(reason: "")
        )
    }

    // MARK: Equality

    func testInvalid_EqualityDependsOnReason() {
        XCTAssertEqual(
            ApplicationValidationError.invalid(reason: "message is empty"),
            ApplicationValidationError.invalid(reason: "message is empty")
        )
        XCTAssertNotEqual(
            ApplicationValidationError.invalid(reason: "message is empty"),
            ApplicationValidationError.invalid(reason: "message is too long")
        )
    }

    // MARK: Typed error conformance

    func testErrors_ThrowAndCastBackAsTypedValues() {
        func throwingError() throws -> ApplicationValidationError {
            throw ApplicationValidationError.invalid(reason: "displayName is empty")
        }
        do {
            _ = try throwingError()
            XCTFail("Expected the error to be thrown")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, ApplicationValidationError.invalid(reason: "displayName is empty"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testApplicationValidationError_DoesNotCollideWithDomainErrors() {
        let validation: any Error = ApplicationValidationError.invalid(reason: "reason")
        let domain: [any Error] = [
            RepositoryError.storageUnavailable,
            CapabilityError.providerUnavailable,
            CredentialStorageError.credentialNotFound,
            ConversationStreamError.streamInProgress,
            ProviderLifecycleError.invalidTransition(from: .registered, to: .ready),
        ]
        for error in domain {
            XCTAssertNil(error as? ApplicationValidationError)
        }
        XCTAssertNotNil(validation as? ApplicationValidationError)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let error = ApplicationValidationError.invalid(reason: "reason")
        let returned = await Task.detached {
            error
        }.value
        XCTAssertEqual(returned, error)
    }
}
