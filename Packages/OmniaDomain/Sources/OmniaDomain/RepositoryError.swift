/// The failures a repository can report (DES-009 §3.5).
public enum RepositoryError: Error, Equatable, Sendable {
    /// The storage is temporarily unavailable; the operation failed.
    case storageUnavailable
}
