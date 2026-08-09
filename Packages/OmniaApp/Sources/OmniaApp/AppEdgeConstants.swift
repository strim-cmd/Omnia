import OmniaDomain

/// The documented application-edge constants the Composition Root composes by
/// (DES-013 §3.2, §3.3, §3.4).
///
/// These are the stable, documented product decisions owned at the application
/// edge: the application-named storage subdirectory, the default workspace name,
/// the bootstrap key that records the resolved default workspace identity, and
/// the default model a configured provider offers when it records none of its
/// own. Each constant is addressed here in exactly one place so writers and
/// readers never diverge (DES-004).
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

    /// The model a configured OpenAI-compatible provider offers by default, when
    /// it records no model of its own: the fallback entry of the `preferredModels`
    /// the Composition Root supplies to selection and to the runtime adapter
    /// binding (DES-013 §3.3). A provider that records its own OpenAI-compatible
    /// model (the OmniRoute combo, or any provider model name) offers that model
    /// instead (DES-011 §3.10).
    public static let defaultModelName = "omnia-coding"
}
