package com.omnia.feature.providers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.omnia.common.Logger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Backs the Providers destination. The M1 shell exposes the empty provider
 * list; the add-provider flow is a later milestone, so the action is disabled.
 */
class ProvidersViewModel(private val dependencies: ProvidersDependencies) : ViewModel() {

    private val _uiState = MutableStateFlow(ProvidersUiState())
    val uiState: StateFlow<ProvidersUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch(dependencies.dispatchers.default) {
            dependencies.logger.info(TAG, "Providers destination opened")
        }
    }

    private companion object {
        const val TAG = "ProvidersViewModel"
    }
}
