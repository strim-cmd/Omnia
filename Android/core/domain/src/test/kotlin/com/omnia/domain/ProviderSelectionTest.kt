package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderSelectionTest {

    @Test
    fun explicitSelection_winsOverAll() {
        val provider = ProviderIdentity("p1")
        val model = ModelReference("m1")
        val policy = ProviderSelectionPolicy()
        val result = policy.select(
            candidates = listOf(
                ProviderCandidate(ProviderIdentity("p2"), listOf(ModelReference("m2"))),
                ProviderCandidate(provider, listOf(model)),
            ),
            explicitSelection = ProviderModelSelection(provider, model),
        )
        assertTrue(result is ProviderSelectionResult.Selected)
        assertEquals(provider, (result as ProviderSelectionResult.Selected).provider)
        assertEquals(model, result.model)
    }

    @Test
    fun explicitSelection_unavailableModel_returnsModelUnavailable() {
        val policy = ProviderSelectionPolicy()
        val result = policy.select(
            candidates = listOf(ProviderCandidate(ProviderIdentity("p1"), listOf(ModelReference("m1")))),
            explicitSelection = ProviderModelSelection(ProviderIdentity("p1"), ModelReference("nonexistent")),
        )
        assertTrue(result is ProviderSelectionResult.ModelUnavailable)
    }

    @Test
    fun automaticSelection_firstByAlphabeticalId() {
        val policy = ProviderSelectionPolicy()
        val result = policy.select(
            candidates = listOf(
                ProviderCandidate(ProviderIdentity("z-provider"), listOf(ModelReference("m"))),
                ProviderCandidate(ProviderIdentity("a-provider"), listOf(ModelReference("m"))),
            ),
        )
        assertTrue(result is ProviderSelectionResult.Selected)
        assertEquals("a-provider", (result as ProviderSelectionResult.Selected).provider.id)
    }

    @Test
    fun noCandidates_returnsFailure() {
        val policy = ProviderSelectionPolicy()
        val result = policy.select(candidates = emptyList())
        assertTrue(result is ProviderSelectionResult.Failure)
    }

    @Test
    fun candidatesWithEmptyModels_skipped() {
        val policy = ProviderSelectionPolicy()
        val result = policy.select(
            candidates = listOf(
                ProviderCandidate(ProviderIdentity("p1"), emptyList()),
            ),
        )
        assertTrue(result is ProviderSelectionResult.Failure)
    }
}
