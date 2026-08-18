package com.omnia.feature.settings

import com.omnia.common.NoOpLogger
import com.omnia.common.SingleDispatcherProvider
import com.omnia.designsystem.theme.ThemeMode
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class SettingsViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private var dataManagementCalled = false

    private fun viewModel(initialTheme: ThemeMode = ThemeMode.SYSTEM): Pair<SettingsViewModel, FakeThemeController> {
        dataManagementCalled = false
        val controller = FakeThemeController(initial = initialTheme)
        val viewModel = SettingsViewModel(
            object : SettingsDependencies {
                override val themeController = controller
                override val logger = NoOpLogger()
                override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
                override val dataManagementService = DataManagementService { dataManagementCalled = true }
            },
        )
        return viewModel to controller
    }

    @Test
    fun initial_state_reflectsController() {
        val (viewModel, _) = viewModel(initialTheme = ThemeMode.LIGHT)
        assertEquals(ThemeMode.LIGHT, viewModel.uiState.value.themeMode)
    }

    @Test
    fun themeSelection_updatesStateDeterministically() {
        val (viewModel, _) = viewModel()

        viewModel.onThemeModeSelected(ThemeMode.DARK)
        assertEquals(ThemeMode.DARK, viewModel.uiState.value.themeMode)

        viewModel.onThemeModeSelected(ThemeMode.SYSTEM)
        assertEquals(ThemeMode.SYSTEM, viewModel.uiState.value.themeMode)
    }

    @Test
    fun themeSelection_forwardsToController() {
        val (viewModel, controller) = viewModel()

        viewModel.onThemeModeSelected(ThemeMode.LIGHT)
        viewModel.onThemeModeSelected(ThemeMode.DARK)

        assertEquals(listOf(ThemeMode.LIGHT, ThemeMode.DARK), controller.selections)
        assertEquals(ThemeMode.DARK, controller.themeMode.value)
    }

    @Test
    fun showClearDataDialog_setsShowClearDataDialog() {
        val (viewModel, _) = viewModel()
        assertFalse(viewModel.uiState.value.showClearDataDialog)
        viewModel.showClearDataDialog()
        assertTrue(viewModel.uiState.value.showClearDataDialog)
    }

    @Test
    fun dismissClearDataDialog_clearsState() {
        val (viewModel, _) = viewModel()
        viewModel.showClearDataDialog()
        assertTrue(viewModel.uiState.value.showClearDataDialog)
        viewModel.dismissClearDataDialog()
        assertFalse(viewModel.uiState.value.showClearDataDialog)
        assertFalse(viewModel.uiState.value.isClearingData)
    }

    @Test
    fun confirmClearData_invokesServiceAndUpdatesState() = runTest {
        val (viewModel, _) = viewModel()
        viewModel.showClearDataDialog()
        assertTrue(viewModel.uiState.value.showClearDataDialog)

        viewModel.confirmClearData()

        assertTrue(dataManagementCalled)
        assertFalse(viewModel.uiState.value.showClearDataDialog)
        assertFalse(viewModel.uiState.value.isClearingData)
    }
}
