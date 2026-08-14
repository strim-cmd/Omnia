import OmniaDomain

/// The documented application-edge constants the Composition Root composes by
/// (DES-013 §3.2, §3.3, §3.4).
///
/// These are the stable, documented product decisions owned at the application
/// edge: the application-named storage subdirectory, the default workspace name,
/// the bootstrap key that records the resolved default workspace identity, and
/// a legacy model-name source compatibility value. Each constant is addressed
/// here in exactly one place so writers and readers never diverge (DES-004).
public enum AppEdgeConstants {
    /// The application-named subdirectory under the platform Application Support
    /// root in which all document stores root (DES-013 §3.2).
    public static let storageRootDirectoryName = "Omnia"

    /// The name of the default workspace created on first launch (DES-013 §3.4).
    public static let defaultWorkspaceName = "Default Workspace"

    /// The global-defaults configuration key that records the resolved default
    /// workspace identity as its canonical string, under the documented,
    /// application-owned name (DES-013 §3.4).
    public static let defaultWorkspaceIdentityKey = ConfigurationKey<String>(
        "app.defaultWorkspaceIdentity"
    )

    /// Legacy reference retained for source compatibility and historical tests.
    /// Production model catalogs never infer this value for an unconfigured
    /// provider; they come from discovery, cache, or an explicit manual model.
    public static let defaultModelName = "omnia-coding"
}
