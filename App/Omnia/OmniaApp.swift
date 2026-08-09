// OmniaMacOSApp — the thin macOS host application (RE-2, PRD-009).
//
// The distribution shell for macOS: the SwiftUI @main App that runs AppLaunch
// (compose the Composition Root, run prepare() resolving the default workspace),
// hosts RootView with the resolved workspace and the settings surface's
// configuration keys, and owns session state at the application edge (DES-013
// §3.5, DES-012 §3.5, §3.6). It is the packaged equivalent of the verified
// SwiftPM executable shell (issue #124): the AppLaunch/RootView contract is the
// single source of truth, so the shells cannot drift.
//
// The host imports only OmniaApp, OmniaPresentation, and SwiftUI — the
// executable's verified import set. It performs no composition, no persistence,
// no networking, no credential operations, and no business logic (ARC-002,
// ARC-006). The shell logic (launch sequencing, session state, failure
// rendering) lives in the Linux-tested AppLaunch surface and the frozen
// presentation surfaces (DES-013 §3.6).

import OmniaApp
import OmniaPresentation
import SwiftUI

/// The macOS app shell (DES-013 §3.5): the SwiftUI `@main` entry point that
/// launches the Composition Root, runs the first-run bootstrap through
/// `AppLaunch`, and hosts `RootView` with the resolved workspace and the
/// settings surface's configuration keys (DES-012 §3.5, §3.6).
///
/// The shell owns session state — the current workspace identity — at the
/// application edge (DES-011 §3.2): the bootstrap delivers it to the shell and
/// the shell hands it to `RootView` as its workspace. The shell renders the
/// launch phase and hosts the frozen surfaces through their seams (DES-012
/// §3.6); it never references an Infrastructure implementation and never
/// performs business, networking, persistence, or credential operations
/// (ARC-002, ARC-006, ARC-009).
///
/// The launch lifecycle adds no persistence beyond the services': every
/// operation persists through the services and repositories (ARC-005). The
/// entry point is verified by review against `project UI standards`.
@main
struct OmniaMacOSApp: App {
    /// The composed application, once the launch sequence completes.
    @State private var launch: AppLaunch?
    /// The launch failure, mapped to concise user-facing copy — presented,
    /// never silent, never the raw error detail (ARC-001, UX audit V4).
    @State private var launchFailure: String?

    var body: some Scene {
        WindowGroup {
            content
                .task { await launch() }
        }
    }

    /// The presented shell: `RootView` once the graph is composed and the
    /// default workspace resolved, a loading state while preparing, and a
    /// failure state when the launch cannot complete.
    @ViewBuilder
    private var content: some View {
        if let launch {
            RootView(
                surface: launch.composition.navigationSurface,
                workspace: launch.workspace,
                configurationKeys: []
            )
        } else if let launchFailure {
            LaunchFailureView(message: launchFailure) {
                Task { await self.launch() }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Runs the launch sequence: composes the object graph and resolves the
    /// default workspace (DES-013 §3.5). A failed launch is re-runnable — the
    /// failure is cleared and the launch retried.
    @MainActor
    private func launch() async {
        guard launch == nil else { return }
        launchFailure = nil
        do {
            launch = try await AppLaunch()
        } catch {
            launchFailure = LaunchFailureCopy.message(for: error)
        }
    }
}

/// The failure state of the launch sequence: the shell presents the failure
/// mapped to concise user-facing copy — never the raw error detail (ARC-001,
/// ARC-005, UX audit V4) — with a retry of the launch.
///
/// The view is native SwiftUI (`project UI standards`); user-visible strings
/// follow the view-layer precedent of the presentation package.
private struct LaunchFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
            Button(String(localized: "try_again"), action: onRetry)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
