import Foundation

/// The concept an identifier identifies.
///
/// A module declares the identity kinds it owns by conforming a marker type to
/// this protocol. The kind binds an identifier to the concept it identifies
/// and is never part of the identifier's value.
public protocol IdentifierKind: Sendable {}

/// A stable, opaque, value-typed token that identifies one domain concept.
///
/// An `Identifier` is bound to a `Kind` that names the concept it identifies.
/// Mixing identifiers of different concepts is prevented by the type system.
/// An identifier is immutable, compares by its underlying unique value, and
/// serializes to a single canonical string.
public struct Identifier<Kind: IdentifierKind>: Hashable, Sendable, Codable {
    private let value: UUID

    /// Creates a new globally unique identifier.
    ///
    /// This is the only way a new identifier enters the system. Generation
    /// succeeds offline and never depends on Omnia state.
    public init() {
        value = UUID()
    }

    /// Restores an identifier from its canonical serialized form.
    ///
    /// Returns `nil` when `canonicalString` is not a well-formed canonical
    /// form. Serialized identity is reconstructed only through this operation.
    public init?(restoring canonicalString: String) {
        guard Self.isWellFormedCanonicalForm(canonicalString),
            let value = UUID(uuidString: canonicalString) else { return nil }
        self.value = value
    }

    private static func isWellFormedCanonicalForm(_ string: String) -> Bool {
        let parts = string.split(separator: "-")
        let expectedLengths = [8, 4, 4, 4, 12]
        guard parts.count == expectedLengths.count else { return false }
        for (part, expected) in zip(parts, expectedLengths) where part.count != expected {
            return false
        }
        return parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
    }

    /// The canonical serialized form of the identifier.
    ///
    /// This is the only public serialized form, used for storage, keys, and
    /// decoding. The form is stable across application versions.
    public var canonicalString: String {
        value.uuidString
    }
}

extension Identifier: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Identifier<\(Kind.self)>(\(canonicalString))"
    }
}

extension Identifier {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let canonicalString = try container.decode(String.self)
        guard let identifier = Identifier(restoring: canonicalString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid canonical form for \(Identifier<Kind>.self)."
            )
        }
        self = identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(canonicalString)
    }
}
