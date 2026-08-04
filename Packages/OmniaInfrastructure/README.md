# OmniaInfrastructure

Implementations of the Domain contracts and platform services: provider adapters, persistence, networking, keychain, and platform services.

- **Layer**: Infrastructure
- **Dependencies**: OmniaDomain, OmniaFoundation
- **Specification**: `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` (ARC-009)

Status: in progress. Storage engine foundation implemented (file-based JSON document store, DES-010 Phase 2), aggregate serializers implemented (Workspace, Conversation, Provider, configuration; DES-010 Phase 3), the four repository implementations over the storage engine and serializers — Workspace, Conversation, Provider, and configuration (FileWorkspaceRepository, FileConversationRepository, FileProviderRepository, FileConfigurationRepository; DES-010 Phases 4–6), and the secure credential storage over the platform backend seam — Keychain on Apple platforms, in-memory elsewhere (SecureCredentialStorage, CredentialStorageBackend, KeychainCredentialStorageBackend, InMemoryCredentialStorageBackend; DES-010 Phase 7).
