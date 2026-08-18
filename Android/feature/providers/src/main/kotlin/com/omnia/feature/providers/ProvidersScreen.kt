package com.omnia.feature.providers

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaButton
import com.omnia.designsystem.components.OmniaCard
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.components.OmniaOutlinedButton
import com.omnia.designsystem.components.OmniaGroupSurface
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProvidersScreen(
    uiState: ProvidersUiState,
    addProviderUiState: AddProviderUiState,
    onBack: () -> Unit,
    onAddProvider: () -> Unit,
    onDismissAddProvider: () -> Unit,
    onEditProvider: (String) -> Unit,
    onDeleteProvider: (String) -> Unit,
    onConfirmDelete: () -> Unit,
    onDismissDelete: () -> Unit,
    onDismissError: () -> Unit,
    onDisplayNameChanged: (String) -> Unit,
    onEndpointChanged: (String) -> Unit,
    onApiKeyChanged: (String) -> Unit,
    onApiKindChanged: (ProviderAPIKind) -> Unit,
    onTestConnection: () -> Unit,
    onSelectedModelChanged: (String) -> Unit,
    onSaveProvider: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.error, addProviderUiState.error) {
        val error = uiState.error ?: addProviderUiState.error
        if (error != null) {
            snackbarHostState.showSnackbar(error)
            onDismissError()
        }
    }

    if (uiState.showAddScreen) {
        AddProviderScreen(
            uiState = addProviderUiState,
            onBack = onDismissAddProvider,
            onDisplayNameChanged = onDisplayNameChanged,
            onEndpointChanged = onEndpointChanged,
            onApiKeyChanged = onApiKeyChanged,
            onApiKindChanged = onApiKindChanged,
            onTestConnection = onTestConnection,
            onSelectedModelChanged = onSelectedModelChanged,
            onSaveProvider = onSaveProvider,
            modifier = modifier,
        )
        return
    }

    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            topBar = {
                TopAppBar(
                    title = { Text(text = stringResource(R.string.providers_title)) },
                    navigationIcon = {
                        OmniaIconButton(
                            icon = OmniaIcons.ArrowBack,
                            contentDescription = stringResource(R.string.providers_back),
                            onClick = onBack,
                        )
                    },
                )
            },
            floatingActionButton = {
                FloatingActionButton(
                    onClick = onAddProvider,
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) {
                    OmniaIconButton(
                        icon = OmniaIcons.Add,
                        contentDescription = stringResource(R.string.providers_add),
                        onClick = onAddProvider,
                    )
                }
            },
            snackbarHost = { SnackbarHost(snackbarHostState) },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            ) {
                if (uiState.isEmpty) {
                    ProvidersEmptyState(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxSize(),
                        onAddProvider = onAddProvider,
                    )
                } else {
                    ProvidersList(
                        providers = uiState.providers,
                        onEditProvider = onEditProvider,
                        onDeleteProvider = onDeleteProvider,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxSize(),
                    )
                }
            }
        }
    }

    if (uiState.deletingProviderId != null) {
        AlertDialog(
            onDismissRequest = onDismissDelete,
            title = { Text(stringResource(R.string.providers_confirm_delete_title)) },
            text = { Text(stringResource(R.string.providers_confirm_delete_message)) },
            confirmButton = {
                OmniaButton(
                    text = stringResource(R.string.providers_confirm),
                    onClick = onConfirmDelete,
                )
            },
            dismissButton = {
                OmniaOutlinedButton(
                    text = stringResource(R.string.providers_cancel),
                    onClick = onDismissDelete,
                )
            },
        )
    }
}

@Composable
private fun ProvidersEmptyState(
    onAddProvider: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(OmniaSpacing.lg),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        androidx.compose.material3.Icon(
            imageVector = OmniaIcons.Providers,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = stringResource(R.string.providers_empty_title),
            modifier = Modifier.padding(top = OmniaSpacing.md),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.providers_empty_body),
            modifier = Modifier.padding(top = OmniaSpacing.xs, bottom = OmniaSpacing.md),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OmniaOutlinedButton(
            text = stringResource(R.string.providers_add),
            onClick = onAddProvider,
            icon = OmniaIcons.Add,
        )
    }
}

@Composable
private fun ProvidersList(
    providers: List<ProvidersUiState.ProviderListItem>,
    onEditProvider: (String) -> Unit,
    onDeleteProvider: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(OmniaSpacing.md),
        verticalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
    ) {
        items(providers, key = { it.id }) { provider ->
            OmniaCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onEditProvider(provider.id) },
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(OmniaSpacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = provider.name,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Row(
                            modifier = Modifier.padding(top = OmniaSpacing.xs),
                            horizontalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            ApiKindBadge(apiKind = provider.apiKind)
                            StateIndicator(state = provider.state)
                            Text(
                                text = stringResource(
                                    R.string.providers_model_count,
                                    provider.modelCount,
                                ),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    OmniaIconButton(
                        icon = OmniaIcons.Delete,
                        contentDescription = stringResource(R.string.providers_delete),
                        onClick = { onDeleteProvider(provider.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ApiKindBadge(apiKind: ProviderAPIKind, modifier: Modifier = Modifier) {
    val label = when (apiKind) {
        ProviderAPIKind.openAICompatible -> stringResource(R.string.providers_openai_compatible)
        ProviderAPIKind.gemini -> stringResource(R.string.providers_gemini)
    }
    OmniaGroupSurface(modifier = modifier) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = OmniaSpacing.sm, vertical = OmniaSpacing.xs),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun StateIndicator(state: ProviderState, modifier: Modifier = Modifier) {
    val color = when (state) {
        ProviderState.ready -> MaterialTheme.colorScheme.tertiary
        ProviderState.unavailable,
        ProviderState.disabled -> MaterialTheme.colorScheme.error
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Box(
        modifier = modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(color),
    )
}

@Composable
fun ProvidersRoute(
    dependencies: ProvidersDependencies,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val viewModel: ProvidersViewModel = viewModel { ProvidersViewModel(dependencies) }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val addProviderUiState by viewModel.addProviderUiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadProviders()
    }

    ProvidersScreen(
        uiState = uiState,
        addProviderUiState = addProviderUiState,
        onBack = onBack,
        onAddProvider = viewModel::showAddProvider,
        onDismissAddProvider = viewModel::dismissAddProvider,
        onEditProvider = viewModel::showEditProvider,
        onDeleteProvider = viewModel::onDeleteProvider,
        onConfirmDelete = viewModel::confirmDelete,
        onDismissDelete = viewModel::dismissDelete,
        onDismissError = viewModel::dismissError,
        onDisplayNameChanged = viewModel::onDisplayNameChanged,
        onEndpointChanged = viewModel::onEndpointChanged,
        onApiKeyChanged = viewModel::onApiKeyChanged,
        onApiKindChanged = viewModel::onApiKindChanged,
        onTestConnection = viewModel::onTestConnection,
        onSelectedModelChanged = viewModel::onSelectedModelChanged,
        onSaveProvider = viewModel::onSaveProvider,
        modifier = modifier,
    )
}
