package com.omnia.feature.providers

import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind

data class AddProviderUiState(
    val displayName: String = "",
    val endpoint: String = "",
    val apiKey: String = "",
    val apiKind: ProviderAPIKind = ProviderAPIKind.openAICompatible,
    val isEditing: Boolean = false,
    val editingProviderId: String? = null,
    val isTesting: Boolean = false,
    val testResult: TestResult? = null,
    val discoveredModels: List<ModelReference> = emptyList(),
    val selectedModel: String = "",
    val isSaving: Boolean = false,
    val error: String? = null,
) {
    val isTestEnabled: Boolean get() =
        displayName.isNotBlank() && endpoint.isNotBlank() && (apiKey.isNotBlank() || isEditing) && !isTesting && !isSaving

    val isSaveEnabled: Boolean get() =
        isTestEnabled && testResult is TestResult.Success && selectedModel.isNotBlank() && !isSaving

    sealed class TestResult {
        data class Success(val models: List<ModelReference>) : TestResult()
        data class Failure(val message: String) : TestResult()
    }
}
