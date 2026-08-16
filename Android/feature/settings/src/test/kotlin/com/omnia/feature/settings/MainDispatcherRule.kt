package com.omnia.feature.settings

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description

@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    val testDispatcher: TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {

    override fun starting(description: Description) {
        Dispatchers.setMain(testDispatcher)
    }

    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}

/** Test [ThemeController] recording every selection. */
class FakeThemeController(initial: com.omnia.designsystem.theme.ThemeMode) : ThemeController {
    private val mutable = MutableStateFlow(initial)
    override val themeMode: kotlinx.coroutines.flow.StateFlow<com.omnia.designsystem.theme.ThemeMode> = mutable
    val selections = mutableListOf<com.omnia.designsystem.theme.ThemeMode>()
    override fun setThemeMode(mode: com.omnia.designsystem.theme.ThemeMode) {
        selections += mode
        mutable.value = mode
    }
}
