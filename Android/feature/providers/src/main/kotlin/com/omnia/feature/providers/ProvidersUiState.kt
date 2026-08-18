package com.omnia.feature.providers

import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderState

data class ProvidersUiState(
    val providers: List<ProviderListItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val showAddScreen: Boolean = false,
    val editingProviderId: String? = null,
    val deletingProviderId: String? = null,
) {
    val isEmpty: Boolean get() = providers.isEmpty() && !isLoading
    val isAddProviderEnabled: Boolean get() = !showAddScreen

    data class ProviderListItem(
        val id: String,
        val name: String,
        val apiKind: ProviderAPIKind,
        val state: ProviderState,
        val modelCount: Int,
    )
}
