import Foundation
import XCTest
@testable import OmniaDomain

private let canonicalRequestA = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalRequestB = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private func isWellFormedCanonical(_ value: String) -> Bool {
    let parts = value.split(separator: "-")
    let lengths = [8, 4, 4, 4, 12]
    guard parts.count == lengths.count else { return false }
    for (part, expected) in zip(parts, lengths) where part.count != expected {
        return false
    }
    return parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
}

final class CapabilityRequestIdentityTests: XCTestCase {

    // MARK: Creation

    func testCreation_ProducesWellFormedCanonicalForm() {
        for _ in 0..<32 {
            XCTAssertTrue(isWellFormedCanonical(CapabilityRequestIdentity().canonicalString))
        }
    }

    func testCreation_ProducesRestorableIdentifiers() throws {
        for _ in 0..<16 {
            let identifier = CapabilityRequestIdentity()
            let restored = try XCTUnwrap(CapabilityRequestIdentity(restoring: identifier.canonicalString))
            XCTAssertEqual(restored, identifier)
        }
    }

    // MARK: Equality

    func testEquality_SameUnderlyingValueIsEqual() throws {
        let a = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        let b = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentUnderlyingValuesAreNotEqual() throws {
        let a = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        let b = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestB))
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentConceptsAreNeverEqual() throws {
        let request = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalRequestA))
        XCTAssertNotEqual(AnyHashable(request), AnyHashable(provider))
    }

    // MARK: Hashability

    func testHashability_EqualIdentifiersHashEqually() throws {
        let a = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        let b = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashability_DictionaryKeysAndSetMembers() throws {
        let a = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        let b = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestB))
        let c = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))

        var dictionary: [CapabilityRequestIdentity: String] = [:]
        dictionary[a] = "alpha"
        dictionary[b] = "beta"

        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary[a], "alpha")
        XCTAssertEqual(dictionary[c], "alpha")

        let set: Set<CapabilityRequestIdentity> = [a, b, c]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(a))
        XCTAssertTrue(set.contains(c))
    }

    // MARK: Uniqueness

    func testUniqueness_GeneratedIdentifiersAreDistinct() {
        var generated: Set<CapabilityRequestIdentity> = []
        for _ in 0..<1_000 {
            generated.insert(CapabilityRequestIdentity())
        }
        XCTAssertEqual(generated.count, 1_000)
    }

    func testUniqueness_GeneratedIdentifiersDifferFromRestored() throws {
        let restored = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        for _ in 0..<64 {
            XCTAssertNotEqual(CapabilityRequestIdentity(), restored)
        }
    }

    // MARK: Serialization

    func testSerialization_RoundTripsExactly() throws {
        let original = CapabilityRequestIdentity()
        let firstRestore = try XCTUnwrap(CapabilityRequestIdentity(restoring: original.canonicalString))
        XCTAssertEqual(firstRestore, original)
        XCTAssertEqual(firstRestore.canonicalString, original.canonicalString)

        let secondRestore = try XCTUnwrap(CapabilityRequestIdentity(restoring: firstRestore.canonicalString))
        XCTAssertEqual(secondRestore, original)
        XCTAssertEqual(secondRestore.canonicalString, original.canonicalString)
    }

    func testSerialization_CanonicalFormIsStable() throws {
        let a = try XCTUnwrap(CapabilityRequestIdentity(restoring: canonicalRequestA))
        for _ in 0..<8 {
            XCTAssertEqual(a.canonicalString, canonicalRequestA)
        }
    }

    func testSerialization_MalformedInputIsRejected() {
        let malformed = [
            "",
            "550E8400",
            "550E8400-E29B-41D4-A716-44665544000",
            "550E8400E29B41D4A716446655440000",
            "not-a-uuid",
            "UUID",
            " 550E8400-E29B-41D4-A716-446655440000",
            "550E8400-E29B-41D4-A716-446655440000 ",
        ]
        for value in malformed {
            XCTAssertNil(CapabilityRequestIdentity(restoring: value), "Expected rejection of \(value)")
        }
    }

    func testSerialization_CodableRoundTripsExactly() throws {
        let identifier = CapabilityRequestIdentity()
        let data = try JSONEncoder().encode(identifier)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(json, "\"\(identifier.canonicalString)\"")

        let decoded = try JSONDecoder().decode(CapabilityRequestIdentity.self, from: data)
        XCTAssertEqual(decoded, identifier)
        XCTAssertEqual(decoded.canonicalString, identifier.canonicalString)
    }

    func testSerialization_CodableRejectsMalformedValues() {
        let malformed = [
            "\"not-a-uuid\"",
            "\"\"",
            "{}",
            "null",
        ]
        for json in malformed {
            let data = Data(json.utf8)
            XCTAssertThrowsError(try JSONDecoder().decode(CapabilityRequestIdentity.self, from: data), json)
        }
    }

    // MARK: Sendability

    func testSendability_UsableInSendableClosure() {
        let identifier = CapabilityRequestIdentity()
        let canonical = identifier.canonicalString
        let read: @Sendable () -> String = { identifier.canonicalString }
        XCTAssertEqual(read(), canonical)
    }

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let identifier = CapabilityRequestIdentity()
        let canonical = identifier.canonicalString
        let returned = await Task.detached {
            identifier.canonicalString
        }.value
        XCTAssertEqual(returned, canonical)
    }
}
