package com.omnia.domain

/**
 * Pure deterministic provider selection policy.
 *
 * Selection priority (highest to lowest):
 * 1. explicitSelection — user-recorded provider/model pair.
 *    If the candidate does not contain both, result is [ProviderSelectionResult.ModelUnavailable].
 * 2. userSelection — user-chosen provider. Its first model is chosen.
 * 3. workspacePreference — workspace-level provider preference.
 * 4. capabilityPreference — capability-level provider preference.
 * 5. Automatic — first selectable candidate sorted by identity string.
 * 6. [ProviderSelectionResult.Failure] — no candidate with non-empty models.
 *
 * Same inputs always produce the same output. Pure and deterministic.
 */
class ProviderSelectionPolicy {

    fun select(
        candidates: List<ProviderCandidate>,
        explicitSelection: ProviderModelSelection? = null,
        userSelection: ProviderIdentity? = null,
        workspacePreference: ProviderIdentity? = null,
        capabilityPreference: ProviderIdentity? = null,
    ): ProviderSelectionResult {
        // Priority 1: explicit selection
        if (explicitSelection != null) {
            val candidate = candidates.find {
                it.provider == explicitSelection.provider &&
                    explicitSelection.model in it.models
            }
            return if (candidate != null) {
                ProviderSelectionResult.Selected(
                    provider = explicitSelection.provider,
                    model = explicitSelection.model,
                )
            } else {
                ProviderSelectionResult.ModelUnavailable(selection = explicitSelection)
            }
        }

        // Priority 2: user selection
        if (userSelection != null) {
            val candidate = candidates.find {
                it.provider == userSelection && it.models.isNotEmpty()
            }
            if (candidate != null) {
                return ProviderSelectionResult.Selected(
                    provider = userSelection,
                    model = candidate.models.first(),
                )
            }
        }

        // Priority 3: workspace preference
        if (workspacePreference != null) {
            val candidate = candidates.find {
                it.provider == workspacePreference && it.models.isNotEmpty()
            }
            if (candidate != null) {
                return ProviderSelectionResult.Selected(
                    provider = workspacePreference,
                    model = candidate.models.first(),
                )
            }
        }

        // Priority 4: capability preference
        if (capabilityPreference != null) {
            val candidate = candidates.find {
                it.provider == capabilityPreference && it.models.isNotEmpty()
            }
            if (candidate != null) {
                return ProviderSelectionResult.Selected(
                    provider = capabilityPreference,
                    model = candidate.models.first(),
                )
            }
        }

        // Priority 5: automatic — first selectable candidate sorted by identity
        val selectable = candidates
            .filter { it.models.isNotEmpty() }
            .sortedBy { it.provider.id }
            .firstOrNull()

        return if (selectable != null) {
            ProviderSelectionResult.Selected(
                provider = selectable.provider,
                model = selectable.models.first(),
            )
        } else {
            ProviderSelectionResult.Failure
        }
    }
}

/** A provider with its offered models. */
data class ProviderCandidate(
    val provider: ProviderIdentity,
    val models: List<ModelReference>,
)

/** The result of a selection attempt. */
sealed class ProviderSelectionResult {
    data class Selected(
        val provider: ProviderIdentity,
        val model: ModelReference,
    ) : ProviderSelectionResult()

    data class ModelUnavailable(val selection: ProviderModelSelection) : ProviderSelectionResult()

    data object Failure : ProviderSelectionResult()
}
