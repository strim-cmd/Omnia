// LaunchFailureCopy — the user-facing copy of a failed launch (UX audit V4).
//
// The launch sequence (AppLaunch) can fail before any surface exists to render
// a typed failure: composing the object graph and resolving the default
// workspace are platform-independent operations whose failures surface as the
// Domain and Application errors of the frozen services (DES-009 §3.9). This
// mapping turns those failures into the concise, human-readable message the
// shells present with the retry action — the raw error detail is never
// presented verbatim (ARC-005). It is platform-independent and Linux-tested
// (DES-013 §3.6); the SwiftUI shells only present the mapped message.

import OmniaApplication
import OmniaDomain

/// The concise, user-meaningful copy of a failed launch (UX audit V4).
///
/// The mapping is platform-independent and covered by Linux tests (DES-013
/// §3.6); the SwiftUI shells present the mapped message with the retry action
/// and never the raw error detail (ARC-005).
public enum LaunchFailureCopy {
    /// Returns the concise user-facing message for a failed launch.
    public static func message(for error: any Error) -> String {
        switch error {
        case let error as RepositoryError:
            return repositoryMessage(for: error)
        case let error as ProviderLifecycleError:
            return providerMessage(for: error)
        case let error as CredentialStorageError:
            return credentialMessage(for: error)
        case let error as ApplicationValidationError:
            return applicationMessage(for: error)
        default:
            return "Omnia couldn't be launched. Please try again."
        }
    }

    private static func repositoryMessage(for error: RepositoryError) -> String {
        switch error {
        case .storageUnavailable:
            return "Storage is temporarily unavailable. Please try again."
        }
    }

    private static func providerMessage(for error: ProviderLifecycleError) -> String {
        switch error {
        case .invalidTransition, .providerNotFound:
            return "A configured provider could not be prepared. Please try again."
        }
    }

    private static func credentialMessage(for error: CredentialStorageError) -> String {
        switch error {
        case .credentialNotFound:
            return "The stored credential could not be found. Check your connection settings."
        case .storageUnavailable:
            return "Secure credential storage is unavailable. Please try again."
        }
    }

    private static func applicationMessage(for error: ApplicationValidationError) -> String {
        switch error {
        case .invalid(let reason):
            return reason
        }
    }
}
