package com.omnia.feature.providers

import com.omnia.common.NoOpLogger
import com.omnia.common.RecordingLogger
import com.omnia.common.SingleDispatcherProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ProvidersViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun initial_state_isEmptyWithAddDisabled() {
        val viewModel = ProvidersViewModel(
            object : ProvidersDependencies {
                override val logger = NoOpLogger()
                override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
            },
        )

        val state = viewModel.uiState.value
        assertTrue(state.isEmpty)
        assertEquals(emptyList<ProviderListItem>(), state.providers)
        assertEquals(false, state.isAddProviderEnabled)
    }

    @Test
    fun open_logsCoarseEventOnly() {
        val logger = RecordingLogger()
        ProvidersViewModel(
            object : ProvidersDependencies {
                override val logger = logger
                override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
            },
        )

        assertTrue(logger.entries.isNotEmpty())
        assertEquals("Providers destination opened", logger.entries.first().message)
    }
}
