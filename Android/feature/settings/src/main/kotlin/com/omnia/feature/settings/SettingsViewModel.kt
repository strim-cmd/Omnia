package com.omnia.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.omnia.designsystem.theme.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Backs the Settings destination. Theme selection is a deterministic,
 * immutable state transition: the controller is the single source of truth for
 * theming, and the ViewModel mirrors each selection immediately.
 */
class SettingsViewModel(private val dependencies: SettingsDependencies) : ViewModel() {

    private val _uiState = MutableStateFlow(
        SettingsUiState(themeMode = dependencies.themeController.themeMode.value),
    )
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch(dependencies.dispatchers.default) {
            dependencies.logger.info(TAG, "Settings destination opened")
        }
    }

    fun onThemeModeSelected(mode: ThemeMode) {
        dependencies.themeController.setThemeMode(mode)
        _uiState.update { it.copy(themeMode = mode) }
    }

    fun showClearDataDialog() {
        _uiState.update { it.copy(showClearDataDialog = true) }
    }

    fun dismissClearDataDialog() {
        _uiState.update { it.copy(showClearDataDialog = false, isClearingData = false) }
    }

    fun confirmClearData() {
        viewModelScope.launch(dependencies.dispatchers.default) {
            _uiState.update { it.copy(isClearingData = true) }
            try {
                dependencies.dataManagementService()
            } finally {
                _uiState.update { it.copy(showClearDataDialog = false, isClearingData = false) }
            }
        }
    }

    private companion object {
        const val TAG = "SettingsViewModel"
    }
}
