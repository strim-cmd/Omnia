package com.omnia.feature.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
    onShowClearDataDialog: () -> Unit,
    onConfirmClearData: () -> Unit,
    onDismissClearDataDialog: () -> Unit,
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
                    .verticalScroll(rememberScrollState())
                    .padding(innerPadding)
                    .padding(OmniaSpacing.md),
                verticalArrangement = Arrangement.spacedBy(OmniaSpacing.md),
            ) {
                AppearanceSection(
                    selectedMode = uiState.themeMode,
                    onThemeModeSelected = onThemeModeSelected,
                )
                AboutRow(onOpenAbout = onOpenAbout)
                Spacer(modifier = Modifier.height(OmniaSpacing.lg))
                ClearDataRow(onShowClearDataDialog = onShowClearDataDialog)
            }
        }
    }

    if (uiState.showClearDataDialog) {
        AlertDialog(
            onDismissRequest = onDismissClearDataDialog,
            title = { Text(text = stringResource(R.string.settings_clear_data_dialog_title)) },
            text = { Text(text = stringResource(R.string.settings_clear_data_dialog_message)) },
            confirmButton = {
                TextButton(
                    onClick = onConfirmClearData,
                    enabled = !uiState.isClearingData,
                ) {
                    Text(
                        text = stringResource(R.string.settings_clear_data_confirm),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(
                    onClick = onDismissClearDataDialog,
                    enabled = !uiState.isClearingData,
                ) {
                    Text(text = stringResource(R.string.settings_clear_data_cancel))
                }
            },
        )
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
private fun ClearDataRow(
    onShowClearDataDialog: () -> Unit,
) {
    OmniaCard(modifier = Modifier.fillMaxWidth(), onClick = onShowClearDataDialog) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(OmniaSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OmniaIconButton(
                icon = OmniaIcons.Delete,
                contentDescription = stringResource(R.string.settings_clear_data),
                onClick = onShowClearDataDialog,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.settings_clear_data),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.error,
                )
                Text(
                    text = stringResource(R.string.settings_clear_data_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
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
        onShowClearDataDialog = viewModel::showClearDataDialog,
        onConfirmClearData = viewModel::confirmClearData,
        onDismissClearDataDialog = viewModel::dismissClearDataDialog,
        modifier = modifier,
    )
}
