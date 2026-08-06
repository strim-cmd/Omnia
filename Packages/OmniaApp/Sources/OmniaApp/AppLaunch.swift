import Foundation
import OmniaDomain

/// The app-shell launch (DES-013 §3.5): the platform-independent launch
/// sequencing that composes the object graph and resolves the default
/// workspace, delivered to the shell as session state.
///
/// The launch sequence composes the `CompositionRoot` — the single assembly
/// point of the complete object graph (DES-013 §3.1) — and runs the first-run
/// bootstrap through `prepare()`, which registers the stored provider
/// connections in the lifecycle service and resolves (or creates) the default
/// workspace (DES-013 §3.3, §3.4). The resolved workspace identity is session
/// state owned at the application edge: it is delivered to the app shell and to
/// `RootView` as its workspace (DES-011 §3.8, DES-012 §3.5).
///
/// The type is the platform-independent side of the build and verification
/// boundary of DES-013 §3.6: it builds and is tested on the Linux build
/// environment, and the SwiftUI `@main` entry point hosts it behind platform
/// availability. It sequences the frozen services and owns no business logic,
/// no orchestration beyond construction and the bootstrap, and no networking,
/// persistence, or credential operations (ARC-002, ARC-006, ARC-009).
public struct AppLaunch: Sendable {
    /// The composed object graph (DES-013 §3.1).
    public let composition: CompositionRoot

    /// The resolved default workspace identity — session state owned at the
    /// application edge and delivered as `RootView.workspace` (DES-011 §3.8).
    public let workspace: WorkspaceIdentity

    /// Runs the launch sequence: composes the object graph at `storageRoot` —
    /// the platform Application Support storage root by default (DES-013 §3.2)
    /// — and resolves the default workspace, creating it on first launch
    /// (DES-013 §3.4).
    ///
    /// The launch is deterministic and idempotent across launches: the same
    /// workspace is resolved until the user removes it, and a launch never
    /// fails on an absent workspace (ARC-005).
    public init(storageRoot: URL? = nil) async throws {
        let composition = CompositionRoot(storageRoot: storageRoot)
        let workspace = try await composition.prepare()
        self.composition = composition
        self.workspace = workspace
    }
}
