import Foundation

/// The domain-agnostic facts about the native platform.
///
/// The platform is captured as facts — its family and its version — never as
/// a platform type or a platform API reference. Consumers decide behavior from
/// these facts, never from platform calls (DES-006, DES-001 §3.3).
public struct Platform: Sendable, Equatable {
    /// The platform family.
    public let family: PlatformFamily
    /// The platform version.
    public let version: SemanticVersion

    /// Creates a platform descriptor from its family and version.
    public init(family: PlatformFamily, version: SemanticVersion) {
        self.family = family
        self.version = version
    }
}

/// The family of the native platform the process runs on.
///
/// The product targets iOS, iPadOS, and macOS (PRODUCT_CHARTER). The family is
/// a fact that names the platform without referencing a platform API (DES-006).
public enum PlatformFamily: Sendable, CaseIterable, Equatable {
    /// The iOS family.
    case iOS
    /// The iPadOS family.
    case iPadOS
    /// The macOS family.
    case macOS
}

/// A factual description of how the process is running.
///
/// The mode is a runtime characteristic, never a configuration decision and
/// never a product decision (DES-006).
public enum ExecutionMode: Sendable, CaseIterable, Equatable {
    /// The shipped product running for users.
    case production
    /// A local development build.
    case development
    /// Running inside a design-time preview.
    case preview
    /// Running under the automated test suite.
    case tests
}

/// A runtime capability the environment can perform.
///
/// A capability is a typed name of what the runtime environment can do. It is
/// distinct from provider capabilities, which are provider concepts owned
/// elsewhere (DES-006, ARC-004).
public struct EnvironmentCapability: Sendable, Equatable, Hashable {
    /// The canonical name of the runtime capability.
    public let name: String

    /// Creates a capability named `name`.
    public init(_ name: String) {
        self.name = name
    }
}

/// An immutable, value-typed descriptor of the execution environment.
///
/// The environment is a fixed set of runtime facts — the platform, the
/// execution mode, and the environment's capabilities. It is domain-agnostic
/// and carries no product meaning. Consumers receive it by composition and
/// never construct, mutate, cache, or replace it (DES-006, ARC-006).
public struct Environment: Sendable, Equatable {
    /// The domain-agnostic facts about the native platform.
    public let platform: Platform
    /// How the process is running.
    public let executionMode: ExecutionMode
    /// The domain-agnostic facts about what the runtime environment can do.
    public let capabilities: Set<EnvironmentCapability>

    /// Creates an environment from its runtime facts.
    ///
    /// Construction is deterministic: it depends on no external state. The
    /// Composition Root constructs the production environment once from facts
    /// supplied by the platform owner; tests construct environments of their
    /// own. Consumers never construct an environment (ARC-006).
    public init(
        platform: Platform,
        executionMode: ExecutionMode,
        capabilities: Set<EnvironmentCapability>
    ) {
        self.platform = platform
        self.executionMode = executionMode
        self.capabilities = capabilities
    }

    /// Returns whether the runtime capability `capability` is available.
    ///
    /// The answer is a fact, determined from the facts the environment was
    /// constructed with. Product decisions are made by consumers, never by the
    /// environment (DES-006).
    public func isAvailable(_ capability: EnvironmentCapability) -> Bool {
        capabilities.contains(capability)
    }
}
