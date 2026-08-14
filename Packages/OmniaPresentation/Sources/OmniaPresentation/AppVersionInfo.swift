import Foundation

/// Display-safe application version metadata resolved from the host bundle.
/// Build settings remain the source of truth; Presentation only reads the two
/// generated Info.plist values needed by About.
public struct AppVersionInfo: Equatable, Sendable {
    public let version: String
    public let build: String

    public init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    /// Resolves the running host's marketing version and build number.
    public static func current(bundle: Bundle = .main) -> AppVersionInfo? {
        resolving(infoDictionary: bundle.infoDictionary)
    }

    /// Kept internal so deterministic tests can verify malformed/missing bundle
    /// metadata without manufacturing an application bundle.
    static func resolving(infoDictionary: [String: Any]?) -> AppVersionInfo? {
        guard
            let version = infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = infoDictionary?["CFBundleVersion"] as? String,
            !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !build.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return AppVersionInfo(version: version, build: build)
    }

    public var localizedDescription: String {
        Localized.appVersionBuild(version: version, build: build)
    }
}
