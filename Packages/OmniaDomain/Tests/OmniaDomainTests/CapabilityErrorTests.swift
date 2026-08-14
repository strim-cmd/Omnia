import XCTest
@testable import OmniaDomain

final class CapabilityErrorTests: XCTestCase {

    // MARK: Frozen taxonomy

    func testTaxonomy_FrozenCasesAreDistinct() {
        let all = [
            CapabilityError.providerUnavailable,
            .networkUnavailable,
            .unauthorized,
            .invalidEndpoint,
            .timedOut,
            .rateLimited,
            .serverFailure,
            .modelUnavailable(model: ModelReference(name: "missing")),
            .invalidRequest,
            .invalidResponse,
            .streamingInterrupted(partialContent: ""),
        ]
        for (index, first) in all.enumerated() {
            for second in all.dropFirst(index + 1) {
                XCTAssertNotEqual(first, second)
            }
        }
    }

    func testTaxonomy_ExhaustiveSwitchCoversTheFrozenCases() {
        func label(of error: CapabilityError) -> String {
            switch error {
            case .providerUnavailable:
                return "providerUnavailable"
            case .networkUnavailable:
                return "networkUnavailable"
            case .unauthorized:
                return "unauthorized"
            case .invalidEndpoint:
                return "invalidEndpoint"
            case .timedOut:
                return "timedOut"
            case .rateLimited:
                return "rateLimited"
            case .serverFailure:
                return "serverFailure"
            case .modelUnavailable:
                return "modelUnavailable"
            case .invalidRequest:
                return "invalidRequest"
            case .invalidResponse:
                return "invalidResponse"
            case .streamingInterrupted:
                return "streamingInterrupted"
            }
        }
        let labels = [
            label(of: .providerUnavailable),
            label(of: .networkUnavailable),
            label(of: .unauthorized),
            label(of: .invalidEndpoint),
            label(of: .timedOut),
            label(of: .rateLimited),
            label(of: .serverFailure),
            label(of: .modelUnavailable(model: ModelReference(name: "missing"))),
            label(of: .invalidRequest),
            label(of: .invalidResponse),
            label(of: .streamingInterrupted(partialContent: "")),
        ]
        XCTAssertEqual(
            labels,
            [
                "providerUnavailable", "networkUnavailable", "unauthorized",
                "invalidEndpoint", "timedOut", "rateLimited", "serverFailure",
                "modelUnavailable", "invalidRequest", "invalidResponse", "streamingInterrupted",
            ]
        )
    }

    // MARK: Equality

    func testProviderUnavailable_IsEqualAcrossInstances() {
        XCTAssertEqual(CapabilityError.providerUnavailable, CapabilityError.providerUnavailable)
    }

    func testInvalidRequest_IsEqualAcrossInstances() {
        XCTAssertEqual(CapabilityError.invalidRequest, CapabilityError.invalidRequest)
    }

    func testInvalidResponse_IsEqualAcrossInstances() {
        XCTAssertEqual(CapabilityError.invalidResponse, CapabilityError.invalidResponse)
    }

    func testStreamingInterrupted_EqualityDependsOnPartialContent() {
        XCTAssertEqual(
            CapabilityError.streamingInterrupted(partialContent: "Hello"),
            CapabilityError.streamingInterrupted(partialContent: "Hello")
        )
        XCTAssertNotEqual(
            CapabilityError.streamingInterrupted(partialContent: "Hello"),
            CapabilityError.streamingInterrupted(partialContent: "Hell")
        )
    }

    // MARK: Partial content preservation

    func testStreamingInterrupted_PreservesPartialContent() throws {
        let error = CapabilityError.streamingInterrupted(partialContent: "Hello, world")
        guard case .streamingInterrupted(let partialContent) = error else {
            return XCTFail("Expected a streaming interruption")
        }
        XCTAssertEqual(partialContent, "Hello, world")
    }

    func testStreamingInterrupted_PreservesIncompleteEmptyPartialContent() {
        XCTAssertEqual(
            CapabilityError.streamingInterrupted(partialContent: ""),
            CapabilityError.streamingInterrupted(partialContent: "")
        )
    }

    // MARK: Typed error conformance

    func testErrors_ThrowAndCastBackAsTypedValues() {
        let errors: [CapabilityError] = [
            .providerUnavailable,
            .networkUnavailable,
            .unauthorized,
            .invalidEndpoint,
            .timedOut,
            .rateLimited,
            .serverFailure,
            .modelUnavailable(model: ModelReference(name: "missing")),
            .invalidRequest,
            .invalidResponse,
            .streamingInterrupted(partialContent: "partial"),
        ]
        for error in errors {
            let thrown: any Error = error
            XCTAssertEqual(thrown as? CapabilityError, error)
        }
    }

    func testCapabilityError_DoesNotCollideWithCredentialStorageError() {
        let capability: any Error = CapabilityError.providerUnavailable
        let credential: any Error = CredentialStorageError.credentialNotFound
        XCTAssertNil(capability as? CredentialStorageError)
        XCTAssertNil(credential as? CapabilityError)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let error = CapabilityError.streamingInterrupted(partialContent: "Hello")
        let returned = await Task.detached {
            error
        }.value
        XCTAssertEqual(returned, error)
    }
}
