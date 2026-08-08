/// A provider that may be selected for a capability (ARC-004, DES-009 §3.2).
///
/// A candidate is a provider identity together with the models the provider
/// offers. Candidates are the ready providers able to deliver the required
/// capability; the set is decided by the caller (DES-009 §3.2).
public struct ProviderCandidate: Equatable, Sendable {
    /// The provider's stable identity.
    public let provider: ProviderIdentity
    /// The models the provider offers for the capability.
    public let models: [ModelReference]

    /// Creates a selection candidate for `provider` offering `models`.
    public init(provider: ProviderIdentity, models: [ModelReference]) {
        self.provider = provider
        self.models = models
    }
}

/// The explicit outcome of provider selection (DES-009 §3.2).
public enum ProviderSelectionResult: Equatable, Sendable {
    /// A provider and a model were selected (ARC-001).
    case selected(provider: ProviderIdentity, model: ModelReference)
    /// No provider can deliver the capability; an explicit failure, never
    /// silent degradation (ARC-004).
    case failure
}

/// The pure selection decision rule (ARC-003 Policy, ARC-004, DES-009 §3.2).
///
/// Selection follows the documented priority: User Selection, then Workspace
/// Preference, then Capability Preference, then Automatic Selection, then
/// Failure. The user's explicit choice always wins; a preference that does not
/// point to a selectable candidate is skipped and the next step applies. When
/// no provider can deliver, the result is an explicit failure, never silent
/// degradation (ARC-004).
///
/// The policy is pure and deterministic: it depends on no external state and
/// the same inputs always produce the same outcome (ARC-003).
public struct ProviderSelectionPolicy: Sendable {
    /// Creates the selection policy.
    public init() {}

    /// Selects a provider among `candidates`, honoring the documented priority.
    ///
    /// A candidate is selectable only when it offers at least one model. When
    /// multiple candidates are eligible at the same step, the deterministic
    /// ordering of provider identities decides the result.
    public func select(
        candidates: [ProviderCandidate],
        userSelection: ProviderIdentity?,
        workspacePreference: ProviderIdentity?,
        capabilityPreference: ProviderIdentity?
    ) -> ProviderSelectionResult {
        if let identity = userSelection, let candidate = selectable(identity, in: candidates) {
            return selected(candidate)
        }
        if let identity = workspacePreference, let candidate = selectable(identity, in: candidates) {
            return selected(candidate)
        }
        if let identity = capabilityPreference, let candidate = selectable(identity, in: candidates) {
            return selected(candidate)
        }
        guard let candidate = candidates
            .filter({ !$0.models.isEmpty })
            .sorted(by: { $0.provider.canonicalString < $1.provider.canonicalString })
            .first
        else {
            return .failure
        }
        return selected(candidate)
    }

    private func selectable(
        _ identity: ProviderIdentity,
        in candidates: [ProviderCandidate]
    ) -> ProviderCandidate? {
        candidates.first { $0.provider == identity && !$0.models.isEmpty }
    }

    private func selected(_ candidate: ProviderCandidate) -> ProviderSelectionResult {
        .selected(provider: candidate.provider, model: candidate.models[0])
    }
}
