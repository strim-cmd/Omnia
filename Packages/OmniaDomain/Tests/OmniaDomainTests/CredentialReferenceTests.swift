import Foundation
import XCTest
@testable import OmniaDomain

private let canonicalCredentialA = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalCredentialB = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private func isWellFormedCanonical(_ value: String) -> Bool {
    let parts = value.split(separator: "-")
    let lengths = [8, 4, 4, 4, 12]
    guard parts.count == lengths.count else { return false }
    for (part, expected) in zip(parts, lengths) where part.count != expected {
        return false
    }
    return parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
}

final class CredentialReferenceTests: XCTestCase {

    // MARK: Creation

    func testCreation_ProducesWellFormedCanonicalForm() {
        for _ in 0..<32 {
            XCTAssertTrue(isWellFormedCanonical(CredentialReference().canonicalString))
        }
    }

    func testCreation_ProducesRestorableReferences() throws {
        for _ in 0..<16 {
            let reference = CredentialReference()
            let restored = try XCTUnwrap(CredentialReference(restoring: reference.canonicalString))
            XCTAssertEqual(restored, reference)
        }
    }

    // MARK: Equality

    func testEquality_SameUnderlyingValueIsEqual() throws {
        let a = try XCTUnwrap(CredentialReference(restoring: canonicalCredentialA))
        let b = try XCTUnwrap(CredentialReference(restoring: canonicalCredentialA))
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentUnderlyingValuesAreNotEqual() throws {
        let a = try XCTUnwrap(CredentialReference(restoring: canonicalCredentialA))
        let b = try XCTUnwrap(CredentialReference(restoring: canonicalCredentialB))
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentConceptsAreNeverEqual() throws {
        let credential = try XCTUnwrap(CredentialReference(restoring: canonicalCredentialA))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalCredentialA))
        XCTAssertNotEqual(AnyHashable(credential), AnyHashable(provider))
    }

    // MARK: Uniqueness

    func testUniqueness_GeneratedReferencesAreDistinct() {
        var generated: Set<CredentialReference> = []
        for _ in 0..<1_000 {
            generated.insert(CredentialReference())
        }
        XCTAssertEqual(generated.count, 1_000)
    }

    // MARK: Serialization

    func testSerialization_RoundTripsExactly() throws {
        let original = CredentialReference()
        let restored = try XCTUnwrap(CredentialReference(restoring: original.canonicalString))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.canonicalString, original.canonicalString)
    }

    func testSerialization_MalformedInputIsRejected() {
        let malformed = [
            "",
            "550E8400",
            "550E8400-E29B-41D4-A716-44665544000",
            "not-a-uuid",
            " 550E8400-E29B-41D4-A716-446655440000",
            "550E8400-E29B-41D4-A716-446655440000 ",
        ]
        for value in malformed {
            XCTAssertNil(CredentialReference(restoring: value), "Expected rejection of \(value)")
        }
    }

    func testSerialization_CodableRoundTripsExactly() throws {
        let reference = CredentialReference()
        let data = try JSONEncoder().encode(reference)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(json, "\"\(reference.canonicalString)\"")

        let decoded = try JSONDecoder().decode(CredentialReference.self, from: data)
        XCTAssertEqual(decoded, reference)
        XCTAssertEqual(decoded.canonicalString, reference.canonicalString)
    }

    // MARK: Sendability

    func testSendability_UsableInSendableClosure() {
        let reference = CredentialReference()
        let canonical = reference.canonicalString
        let read: @Sendable () -> String = { reference.canonicalString }
        XCTAssertEqual(read(), canonical)
    }

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let reference = CredentialReference()
        let canonical = reference.canonicalString
        let returned = await Task.detached {
            reference.canonicalString
        }.value
        XCTAssertEqual(returned, canonical)
    }
}
