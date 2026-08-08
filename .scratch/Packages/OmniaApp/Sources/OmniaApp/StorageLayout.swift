import Foundation

/// The storage layout of the application (DES-013 §3.2): one directory per
/// repository, rooted in the platform Application Support directory, under a
/// stable application-named subdirectory, and created lazily on the first save.
///
/// The layout is derived once at composition and never re-derived: each
/// repository type roots its store in its own directory, because documents are
/// addressed by identity key alone and different aggregates must not share a
/// namespace. Credentials never enter any directory of the layout; they live
/// only in the secure credential storage (ARC-005).
public enum StorageLayout {
    /// The platform Application Support root of the storage layout (DES-013
    /// §3.2): the Application Support directory of the current user domain plus
    /// the stable, application-named subdirectory.
    ///
    /// The root is derived from `FileManager.urls(for: .applicationSupportDirectory,
    /// in: .userDomainMask)`, which the Foundation provides on every supported
    /// platform, so the Composition Root is buildable and testable on the Linux
    /// build environment. The subdirectory is created lazily on the first save,
    /// never eagerly.
    public static func platformRoot() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base.appendingPathComponent(
            AppEdgeConstants.storageRootDirectoryName,
            isDirectory: true
        )
    }
}
