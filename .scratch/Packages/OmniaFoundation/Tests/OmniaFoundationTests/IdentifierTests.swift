import Foundation
import XCTest
@testable import OmniaFoundation

struct WorkspaceKind: IdentifierKind {}
struct ConversationKind: IdentifierKind {}

private let canonicalWorkspaceA = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalWorkspaceB = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private func isWellFormedCanonical(_ value: String) -> Bool {
    let parts = value.split(separator: "-")
    let lengths = [8, 4, 4, 4, 12]
    guard parts.count == lengths.count else { return false }
    for (part, expected) in zip(parts, lengths) where part.count != expected {
        return false
    }
    return parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
}

final class IdentifierTests: XCTestCase {

    // MARK: Creation

    func testCreation_ProducesWellFormedCanonicalForm() {
        for _ in 0..<32 {
            let identifier = Identifier<WorkspaceKind>()
            XCTAssertTrue(isWellFormedCanonical(identifier.canonicalString))
        }
    }

    func testCreation_ProducesRestorableIdentifiers() {
        for _ in 0..<16 {
            let identifier = Identifier<WorkspaceKind>()
            let restored = Identifier<WorkspaceKind>(restoring: identifier.canonicalString)
            XCTAssertEqual(restored, identifier)
        }
    }

    // MARK: Equality

    func testEquality_SameUnderlyingValueIsEqual() throws {
        let a = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let b = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentUnderlyingValuesAreNotEqual() throws {
        let a = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let b = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceB))
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentConceptsAreNeverEqual() throws {
        let workspace = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let conversation = try XCTUnwrap(Identifier<ConversationKind>(restoring: canonicalWorkspaceA))
        XCTAssertNotEqual(AnyHashable(workspace), AnyHashable(conversation))
    }

    // MARK: Hashability

    func testHashability_EqualIdentifiersHashEqually() throws {
        let a = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let b = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashability_DictionaryKeysAndSetMembers() throws {
        let a = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let b = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceB))
        let c = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))

        var dictionary: [Identifier<WorkspaceKind>: String] = [:]
        dictionary[a] = "alpha"
        dictionary[b] = "beta"

        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary[a], "alpha")
        XCTAssertEqual(dictionary[c], "alpha")

        let set: Set<Identifier<WorkspaceKind>> = [a, b, c]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(a))
        XCTAssertTrue(set.contains(c))
    }

    // MARK: Uniqueness

    func testUniqueness_GeneratedIdentifiersAreDistinct() {
        var generated: Set<Identifier<WorkspaceKind>> = []
        for _ in 0..<1_000 {
            generated.insert(Identifier<WorkspaceKind>())
        }
        XCTAssertEqual(generated.count, 1_000)
    }

    func testUniqueness_GeneratedIdentifiersDifferFromRestored() throws {
        let restored = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        for _ in 0..<64 {
            XCTAssertNotEqual(Identifier<WorkspaceKind>(), restored)
        }
    }

    // MARK: Serialization

    func testSerialization_RoundTripsExactly() throws {
        let original = Identifier<WorkspaceKind>()
        let firstRestore = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: original.canonicalString))
        XCTAssertEqual(firstRestore, original)
        XCTAssertEqual(firstRestore.canonicalString, original.canonicalString)

        let secondRestore = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: firstRestore.canonicalString))
        XCTAssertEqual(secondRestore, original)
        XCTAssertEqual(secondRestore.canonicalString, original.canonicalString)
    }

    func testSerialization_CanonicalFormIsStable() throws {
        let a = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        for _ in 0..<8 {
            XCTAssertEqual(a.canonicalString, canonicalWorkspaceA)
        }
    }

    func testSerialization_CanonicalFormIsNonEmptyASCIISafe() {
        for _ in 0..<32 {
            let canonical = Identifier<WorkspaceKind>().canonicalString
            XCTAssertFalse(canonical.isEmpty)
            XCTAssertTrue(isWellFormedCanonical(canonical))
        }
    }

    func testSerialization_MalformedInputIsRejected() {
        let malformed = [
            "",
            "550E8400",
            "550E8400-E29B-41D4-A716-44665544000",
            "550E8400-E29B-41D4-A716-446655440000-",
            "550E8400E29B41D4A716446655440000",
            "550E8400-E29B-41D4-A716-44665544000G",
            "550E8400-E29B-41D4-A716-4466554400 0",
            "550E8400-E29B-41D4-A716-4466554400é",
            "not-a-uuid",
            "UUID",
            " 550E8400-E29B-41D4-A716-446655440000",
            "550E8400-E29B-41D4-A716-446655440000 ",
        ]
        for value in malformed {
            XCTAssertNil(Identifier<WorkspaceKind>(restoring: value), "Expected rejection of \(value)")
        }
    }

    func testSerialization_CodableRoundTripsExactly() throws {
        let identifier = Identifier<WorkspaceKind>()
        let data = try JSONEncoder().encode(identifier)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(json, "\"\(identifier.canonicalString)\"")

        let decoded = try JSONDecoder().decode(Identifier<WorkspaceKind>.self, from: data)
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
            XCTAssertThrowsError(try JSONDecoder().decode(Identifier<WorkspaceKind>.self, from: data), json)
        }
    }

    // MARK: Sendability

    func testSendability_UsableInSendableClosure() {
        let identifier = Identifier<WorkspaceKind>()
        let canonical = identifier.canonicalString
        let read: @Sendable () -> String = { identifier.canonicalString }
        XCTAssertEqual(read(), canonical)
    }

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let identifier = Identifier<WorkspaceKind>()
        let canonical = identifier.canonicalString
        let returned = await Task.detached {
            identifier.canonicalString
        }.value
        XCTAssertEqual(returned, canonical)
    }

    // MARK: Immutability

    func testImmutability_ValueCanonicalFormAndEqualityNeverChange() throws {
        let identifier = Identifier<WorkspaceKind>()
        let canonical = identifier.canonicalString

        var set: Set<Identifier<WorkspaceKind>> = [identifier]
        let dictionaryKey = identifier

        XCTAssertEqual(set.insert(identifier).inserted, false)
        XCTAssertTrue(set.contains(dictionaryKey))
        XCTAssertEqual(identifier.canonicalString, canonical)

        let restored = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonical))
        XCTAssertEqual(restored, identifier)
        XCTAssertEqual(restored.hashValue, identifier.hashValue)
        XCTAssertEqual(restored.canonicalString, canonical)
    }

    // MARK: Debug representation

    func testDebugRepresentation_DistinctFromCanonical() throws {
        let identifier = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        XCTAssertNotEqual(identifier.debugDescription, identifier.canonicalString)
        XCTAssertNotEqual(String(describing: identifier), identifier.canonicalString)
    }

    func testDebugRepresentation_IndicatesKind() throws {
        let workspace = try XCTUnwrap(Identifier<WorkspaceKind>(restoring: canonicalWorkspaceA))
        let conversation = try XCTUnwrap(Identifier<ConversationKind>(restoring: canonicalWorkspaceA))
        XCTAssertTrue(workspace.debugDescription.contains("WorkspaceKind"))
        XCTAssertTrue(conversation.debugDescription.contains("ConversationKind"))
        XCTAssertNotEqual(workspace.debugDescription, conversation.debugDescription)
        XCTAssertTrue(workspace.debugDescription.contains(workspace.canonicalString))
    }
}
