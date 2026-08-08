import Foundation
import OmniaDomain

/// The stored representation of one typed configuration value at one level
/// (DES-010 §3.3).
///
/// The value is typed: `Value` is the same type the `ConfigurationKey` names.
/// A value may hold a `CredentialReference` pointer; the stored configuration
/// holds references only, never credentials or secrets (ARC-005).
internal struct ConfigurationEntryDTO<Value: Codable & Equatable & Sendable>: Codable, Sendable {
    let key: String
    let level: String
    let value: Value
}

/// The stored representation of a configuration snapshot: typed values per
/// `ConfigurationLevel` (DES-010 §3.3, DES-009 §3.6).
///
/// Entries are stored in deterministic order — by level priority, then key
/// name — so the persisted form round-trips exactly across versions (DES-004
/// §4, ARC-005).
internal struct ConfigurationValuesDTO<Value: Codable & Equatable & Sendable>: Codable, Sendable {
    let values: [ConfigurationEntryDTO<Value>]
}

/// Maps configuration values to and from their stored representation
/// (DES-010 §3.3).
///
/// The serializer owns no business rules (ARC-005): resolution across levels
/// belongs to `ConfigurationResolutionPolicy`, never to this serializer
/// (DES-009 §3.6). It stores typed values per level and key exactly as given;
/// it never stores credentials or secrets, only the values (which may be
/// `CredentialReference` pointers).
internal struct ConfigurationSerializer<Value: Codable & Equatable & Sendable>: Sendable {
    /// Encodes a configuration snapshot to its deterministic JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the snapshot cannot
    ///   be encoded.
    func encode(_ values: [ConfigurationLevel: [ConfigurationKey<Value>: Value]]) throws -> Data {
        var entries: [ConfigurationEntryDTO<Value>] = []
        for level in ConfigurationLevel.storageOrder {
            guard let keyed = values[level] else { continue }
            for key in keyed.keys.sorted(by: { $0.name < $1.name }) {
                guard let value = keyed[key] else { continue }
                entries.append(
                    ConfigurationEntryDTO(key: key.name, level: level.serializedName, value: value)
                )
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(ConfigurationValuesDTO(values: entries))
    }

    /// Restores a configuration snapshot from its JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid configuration representation.
    func decode(from data: Data) throws -> [ConfigurationLevel: [ConfigurationKey<Value>: Value]] {
        let dto: ConfigurationValuesDTO<Value>
        do {
            dto = try JSONDecoder().decode(ConfigurationValuesDTO<Value>.self, from: data)
        } catch {
            throw RepositoryError.storageUnavailable
        }
        var result: [ConfigurationLevel: [ConfigurationKey<Value>: Value]] = [:]
        for entry in dto.values {
            guard let level = ConfigurationLevel(serializedName: entry.level) else {
                throw RepositoryError.storageUnavailable
            }
            result[level, default: [:]][ConfigurationKey(entry.key)] = entry.value
        }
        return result
    }
}

extension ConfigurationLevel {
    /// The fixed storage order: provider settings, then workspace overrides,
    /// then global defaults, then capability preferences (ARC-004, ARC-007).
    static let storageOrder: [ConfigurationLevel] = [
        .providerSettings,
        .workspaceOverride,
        .globalDefault,
        .capabilityPreference,
    ]

    var serializedName: String {
        switch self {
        case .providerSettings: return "providerSettings"
        case .workspaceOverride: return "workspaceOverride"
        case .globalDefault: return "globalDefault"
        case .capabilityPreference: return "capabilityPreference"
        }
    }

    init?(serializedName: String) {
        switch serializedName {
        case "providerSettings": self = .providerSettings
        case "workspaceOverride": self = .workspaceOverride
        case "globalDefault": self = .globalDefault
        case "capabilityPreference": self = .capabilityPreference
        default: return nil
        }
    }
}
