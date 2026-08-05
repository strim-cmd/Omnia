import Foundation

/// A stable, immutable semantic version: `major.minor.patch`.
///
/// Versions compare deterministically and order consistently with equality.
/// The value is the shared representation for versioned facts such as platform
/// versions (DES-006); it carries no product meaning.
public struct SemanticVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    /// The major component.
    public let major: Int
    /// The minor component.
    public let minor: Int
    /// The patch component.
    public let patch: Int

    /// Creates a semantic version from its components.
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Returns whether `lhs` orders before `rhs`.
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }

    /// The `major.minor.patch` representation.
    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}
