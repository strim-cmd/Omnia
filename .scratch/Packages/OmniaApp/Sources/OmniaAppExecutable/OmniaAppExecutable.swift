// OmniaAppExecutable — the macOS app shell, entry point, and lifecycle.
//
// The executable entry point of Omnia (DES-013 §3.5): the SwiftUI @main App
// that launches the Composition Root, runs the first-run bootstrap, and hosts
// RootView with the resolved workspace and the settings surface's configuration
// keys (DES-012 §3.5, §3.6). The launch sequencing lives in the
// platform-independent AppLaunch; the shell renders the launch phase and hosts
// the frozen presentation surfaces — it owns session state at the application
// edge and never references an Infrastructure implementation (ARC-006).
//
// The entry point is Apple-platform code, isolated behind platform
// availability; it is not exercised by the Linux test environment (DES-013
// §3.6). On other platforms a no-op entry point keeps the executable target
// building on the standard build environment.

#if canImport(SwiftUI)

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
/// entry point is verified by review against `.ai/standards/UI.md`.
@main
struct OmniaAppShell: App {
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
    ///
    /// The MVP hosts `RootView` with no user-facing configuration rows — the
    /// settings surface presents the connection state, and the endpoint is
    /// collected with the connection declaration (DES-012 §3.4); a typed
    /// configuration key the settings surface presents is added only when the
    /// application edge defines one.
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
/// The view is native SwiftUI (`.ai/standards/UI.md`); user-visible strings
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
            Button("Try Again", action: onRetry)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#else

// Other platforms: a no-op entry point keeps the executable target building on
// the standard build environment; the app shell is Apple-platform only
// (DES-013 §3.6).

@main
enum OmniaLinuxLauncher {
    static func main() {
        // The Omnia macOS app shell requires an Apple platform.
    }
}

#endif
