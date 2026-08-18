package com.omnia.feature.providers

import com.omnia.common.NoOpLogger
import com.omnia.common.SingleDispatcherProvider
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ProvidersViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun buildDependencies(logger: com.omnia.common.Logger = NoOpLogger()) = object : ProvidersDependencies {
        override val logger = logger
        override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
        override val providerConnectionService get() = throw NotImplementedError("not used in these tests")
        override val providerModelService get() = throw NotImplementedError("not used in these tests")
        override val providerValidationService get() = throw NotImplementedError("not used in these tests")
    }

    @Test
    fun initial_state_isEmptyWithAddDisabled() {
        val viewModel = ProvidersViewModel(buildDependencies())

        val state = viewModel.uiState.value
        assertTrue(state.isEmpty)
        assertTrue(state.providers.isEmpty())
        assertTrue(state.isAddProviderEnabled)
    }

    @Test
    fun initial_addProviderUiState_isDefault() {
        val viewModel = ProvidersViewModel(buildDependencies())

        val addState = viewModel.addProviderUiState.value
        assertTrue(addState.displayName.isEmpty())
        assertTrue(addState.endpoint.isEmpty())
        assertTrue(addState.apiKey.isEmpty())
    }
}
