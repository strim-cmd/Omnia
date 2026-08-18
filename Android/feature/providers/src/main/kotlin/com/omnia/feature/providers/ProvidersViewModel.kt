package com.omnia.feature.providers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.omnia.common.SemanticVersion
import com.omnia.application.ConfigureProviderRequest
import com.omnia.application.ProviderConnectionTestRequest
import com.omnia.application.ProviderUpdateRequest
import com.omnia.domain.Capability
import com.omnia.domain.Credential
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderCapabilities
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLimits
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ProvidersViewModel(private val dependencies: ProvidersDependencies) : ViewModel() {

    private val _uiState = MutableStateFlow(ProvidersUiState())
    val uiState: StateFlow<ProvidersUiState> = _uiState.asStateFlow()

    private val _addProviderUiState = MutableStateFlow(AddProviderUiState())
    val addProviderUiState: StateFlow<AddProviderUiState> = _addProviderUiState.asStateFlow()

    init {
    }

    fun loadProviders() {
        viewModelScope.launch(dependencies.dispatchers.default) {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val providers = dependencies.providerConnectionService.allProviders()
                val items = providers.map { provider ->
                    val catalog = dependencies.providerModelService.cachedCatalog(provider.identity)
                    val apiKind = dependencies.providerConnectionService.apiKind(provider.identity)
                    ProvidersUiState.ProviderListItem(
                        id = provider.identity.id,
                        name = provider.connection.metadata.displayName,
                        apiKind = apiKind,
                        state = provider.state,
                        modelCount = catalog.models.size,
                    )
                }
                _uiState.update { it.copy(providers = items, isLoading = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Unknown error") }
            }
        }
    }

    fun showAddProvider() {
        _addProviderUiState.value = AddProviderUiState()
        _uiState.update { it.copy(showAddScreen = true, editingProviderId = null) }
    }

    fun showEditProvider(id: String) {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val identity = ProviderIdentity(id)
                val providers = dependencies.providerConnectionService.allProviders()
                val provider = providers.find { it.identity.id == id }
                val name = provider?.connection?.metadata?.displayName ?: ""
                val endpoint = dependencies.providerConnectionService.endpoint(identity) ?: ""
                val apiKind = dependencies.providerConnectionService.apiKind(identity)
                val model = dependencies.providerConnectionService.model(identity) ?: ""

                _addProviderUiState.value = AddProviderUiState(
                    displayName = name,
                    endpoint = endpoint,
                    apiKind = apiKind,
                    isEditing = true,
                    editingProviderId = id,
                    selectedModel = model,
                    testResult = if (model.isNotBlank()) {
                        AddProviderUiState.TestResult.Success(emptyList())
                    } else {
                        null
                    },
                )
                _uiState.update { it.copy(showAddScreen = true, editingProviderId = id) }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Unknown error") }
            }
        }
    }

    fun dismissAddProvider() {
        _addProviderUiState.value = AddProviderUiState()
        _uiState.update { it.copy(showAddScreen = false, editingProviderId = null) }
    }

    fun onDisplayNameChanged(name: String) {
        _addProviderUiState.update { it.copy(displayName = name, testResult = null) }
    }

    fun onEndpointChanged(endpoint: String) {
        _addProviderUiState.update { it.copy(endpoint = endpoint, testResult = null) }
    }

    fun onApiKeyChanged(key: String) {
        _addProviderUiState.update { it.copy(apiKey = key, testResult = null) }
    }

    fun onApiKindChanged(kind: ProviderAPIKind) {
        _addProviderUiState.update { it.copy(apiKind = kind, testResult = null) }
    }

    fun onTestConnection() {
        val state = _addProviderUiState.value
        viewModelScope.launch(dependencies.dispatchers.default) {
            _addProviderUiState.update { it.copy(isTesting = true, testResult = null) }
            try {
                val identity = if (state.isEditing && state.editingProviderId != null) {
                    ProviderIdentity(state.editingProviderId)
                } else {
                    null
                }
                val credential = if (state.apiKey.isNotBlank()) Credential.of(state.apiKey) else null
                val request = ProviderConnectionTestRequest(
                    providerIdentity = identity,
                    endpoint = state.endpoint,
                    credential = credential,
                    apiKind = state.apiKind,
                )
                val result = dependencies.providerValidationService.test(request)
                _addProviderUiState.update {
                    it.copy(
                        isTesting = false,
                        testResult = AddProviderUiState.TestResult.Success(result.models),
                        discoveredModels = result.models,
                    )
                }
            } catch (e: Exception) {
                _addProviderUiState.update {
                    it.copy(
                        isTesting = false,
                        testResult = AddProviderUiState.TestResult.Failure(
                            formatErrorMessage(e),
                        ),
                    )
                }
            }
        }
    }

    fun onSelectedModelChanged(model: String) {
        _addProviderUiState.update { it.copy(selectedModel = model) }
    }

    fun onSaveProvider() {
        val state = _addProviderUiState.value
        viewModelScope.launch(dependencies.dispatchers.default) {
            _addProviderUiState.update { it.copy(isSaving = true, error = null) }
            try {
                if (state.isEditing && state.editingProviderId != null) {
                    val identity = ProviderIdentity(state.editingProviderId)
                    val request = ProviderUpdateRequest(
                        displayName = state.displayName,
                        capabilities = ProviderCapabilities(setOf(Capability.streaming)),
                        limits = ProviderLimits(),
                        version = SemanticVersion(1, 0, 0),
                    )
                    dependencies.providerConnectionService.update(
                        request = request,
                        identity = identity,
                        endpoint = state.endpoint,
                        model = state.selectedModel,
                        apiKind = state.apiKind,
                    )
                } else {
                    val request = ConfigureProviderRequest(
                        displayName = state.displayName,
                        credential = Credential.of(state.apiKey),
                        capabilities = ProviderCapabilities(setOf(Capability.streaming)),
                        limits = ProviderLimits(),
                        version = SemanticVersion(1, 0, 0),
                    )
                    dependencies.providerConnectionService.configure(
                        request = request,
                        endpoint = state.endpoint,
                        model = state.selectedModel,
                        apiKind = state.apiKind,
                    )
                }
                _addProviderUiState.update { it.copy(isSaving = false) }
                dismissAddProvider()
                loadProviders()
            } catch (e: Exception) {
                _addProviderUiState.update {
                    it.copy(isSaving = false, error = formatErrorMessage(e))
                }
            }
        }
    }

    fun onDeleteProvider(id: String) {
        _uiState.update { it.copy(deletingProviderId = id) }
    }

    fun confirmDelete() {
        val id = _uiState.value.deletingProviderId ?: return
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                dependencies.providerConnectionService.remove(ProviderIdentity(id))
                _uiState.update { it.copy(deletingProviderId = null) }
                loadProviders()
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(deletingProviderId = null, error = formatErrorMessage(e))
                }
            }
        }
    }

    fun dismissDelete() {
        _uiState.update { it.copy(deletingProviderId = null) }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
        _addProviderUiState.update { it.copy(error = null) }
    }

    private fun formatErrorMessage(e: Throwable): String {
        val raw = e.message ?: "Unknown error"
        return when {
            raw.contains("invalidCredential") -> "Invalid API key or credential"
            raw.contains("unreachable") -> "Cannot reach server. Check endpoint URL and internet connection."
            raw.contains("invalidEndpoint") -> "Invalid endpoint URL"
            raw.contains("modelUnavailable") -> "The specified model is not available"
            raw.contains("rateLimited") -> "Rate limit exceeded. Please try again later."
            raw.contains("timedOut") -> "Connection timed out"
            raw.contains("serverFailure") -> "Server returned an error"
            raw.contains("invalidResponse") -> "Invalid response from server"
            raw.startsWith("Invalid endpoint:") -> raw
            raw.startsWith("Credential is required") -> "API key is required"
            else -> raw
        }
    }
}
