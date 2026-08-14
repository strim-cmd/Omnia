/// The application-level destructive data-management operation used by
/// Settings. The Composition Root supplies the concrete, ordered cleanup over
/// repositories, attachment storage, configuration, and secure credentials;
/// Presentation receives only this capability and cannot reach storage APIs.
public struct DataManagementService: Sendable {
    private let clearAllOperation: @Sendable () async throws -> Void

    public init(
        clearAll: @escaping @Sendable () async throws -> Void
    ) {
        self.clearAllOperation = clearAll
    }

    /// Removes all user chat data, attachment bytes, provider connections and
    /// credentials, and app settings in the scope documented by the Settings
    /// confirmation. The retained workspace shell keeps the running UI valid.
    public func clearAll() async throws {
        try await clearAllOperation()
    }
}
