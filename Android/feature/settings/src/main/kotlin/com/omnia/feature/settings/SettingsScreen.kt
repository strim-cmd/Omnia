package com.omnia.feature.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaCard
import com.omnia.designsystem.components.OmniaGroupSurface
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons
import com.omnia.designsystem.theme.ThemeMode

/**
 * Stateless Settings screen. Renders whatever [uiState] it is given.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    uiState: SettingsUiState,
    onThemeModeSelected: (ThemeMode) -> Unit,
    onBack: () -> Unit,
    onOpenAbout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            topBar = {
                TopAppBar(
                    title = { Text(text = stringResource(R.string.settings_title)) },
                    navigationIcon = {
                        OmniaIconButton(
                            icon = OmniaIcons.ArrowBack,
                            contentDescription = stringResource(R.string.settings_back),
                            onClick = onBack,
                        )
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(OmniaSpacing.md),
                verticalArrangement = Arrangement.spacedBy(OmniaSpacing.md),
            ) {
                AppearanceSection(
                    selectedMode = uiState.themeMode,
                    onThemeModeSelected = onThemeModeSelected,
                )
                AboutRow(onOpenAbout = onOpenAbout)
            }
        }
    }
}

@Composable
private fun AppearanceSection(
    selectedMode: ThemeMode,
    onThemeModeSelected: (ThemeMode) -> Unit,
) {
    Text(
        text = stringResource(R.string.settings_appearance),
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onBackground,
    )
    OmniaGroupSurface(modifier = Modifier.fillMaxWidth()) {
        Column {
            ThemeModeRow(
                label = stringResource(R.string.settings_theme_system),
                selected = selectedMode == ThemeMode.SYSTEM,
                onClick = { onThemeModeSelected(ThemeMode.SYSTEM) },
            )
            ThemeModeRow(
                label = stringResource(R.string.settings_theme_light),
                selected = selectedMode == ThemeMode.LIGHT,
                onClick = { onThemeModeSelected(ThemeMode.LIGHT) },
            )
            ThemeModeRow(
                label = stringResource(R.string.settings_theme_dark),
                selected = selectedMode == ThemeMode.DARK,
                onClick = { onThemeModeSelected(ThemeMode.DARK) },
            )
        }
    }
}

@Composable
private fun ThemeModeRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onClick)
        Text(
            text = label,
            modifier = Modifier.padding(start = OmniaSpacing.sm),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun AboutRow(
    onOpenAbout: () -> Unit,
) {
    OmniaCard(modifier = Modifier.fillMaxWidth(), onClick = onOpenAbout) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(OmniaSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.settings_about),
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = ">",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun SettingsRoute(
    dependencies: SettingsDependencies,
    onBack: () -> Unit,
    onOpenAbout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val viewModel: SettingsViewModel = viewModel { SettingsViewModel(dependencies) }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    SettingsScreen(
        uiState = uiState,
        onThemeModeSelected = viewModel::onThemeModeSelected,
        onBack = onBack,
        onOpenAbout = onOpenAbout,
        modifier = modifier,
    )
}
