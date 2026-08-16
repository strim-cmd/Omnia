package com.omnia.feature.providers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaCard
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.components.OmniaOutlinedButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons

/**
 * Stateless Providers screen. Renders whatever [uiState] it is given.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProvidersScreen(
    uiState: ProvidersUiState,
    onBack: () -> Unit,
    onAddProvider: () -> Unit,
    modifier: Modifier = Modifier,
) {
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
                        isAddProviderEnabled = uiState.isAddProviderEnabled,
                    )
                } else {
                    ProvidersList(
                        providers = uiState.providers,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxSize(),
                    )
                }
            }
        }
    }
}

@Composable
private fun ProvidersEmptyState(
    onAddProvider: () -> Unit,
    isAddProviderEnabled: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(OmniaSpacing.lg),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
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
            enabled = isAddProviderEnabled,
            icon = OmniaIcons.Add,
        )
    }
}

@Composable
private fun ProvidersList(
    providers: List<ProviderListItem>,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(OmniaSpacing.md),
        verticalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
    ) {
        items(providers, key = { it.id }) { provider ->
            OmniaCard(modifier = Modifier.fillMaxSize()) {
                Text(
                    text = provider.name,
                    modifier = Modifier.padding(OmniaSpacing.md),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
    }
}

@Composable
fun ProvidersRoute(
    dependencies: ProvidersDependencies,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val viewModel: ProvidersViewModel = viewModel { ProvidersViewModel(dependencies) }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ProvidersScreen(
        uiState = uiState,
        onBack = onBack,
        onAddProvider = {},
        modifier = modifier,
    )
}
