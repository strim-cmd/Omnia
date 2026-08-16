package com.omnia.feature.chat

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons

/**
 * Stateless Chat screen. Renders whatever [uiState] it is given, so previews and
 * tests exercise the full surface without a ViewModel.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    uiState: ChatUiState,
    onOpenProviders: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            topBar = {
                TopAppBar(
                    title = {
                        Text(text = stringResource(R.string.chat_title))
                    },
                    actions = {
                        OmniaIconButton(
                            icon = OmniaIcons.Providers,
                            contentDescription = stringResource(R.string.chat_open_providers),
                            onClick = onOpenProviders,
                        )
                        OmniaIconButton(
                            icon = OmniaIcons.Settings,
                            contentDescription = stringResource(R.string.chat_open_settings),
                            onClick = onOpenSettings,
                        )
                    },
                )
            },
        ) { innerPadding ->
            if (!uiState.hasMessages) {
                ChatEmptyState(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                )
            }
        }
    }
}

@Composable
private fun ChatEmptyState(
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(OmniaSpacing.lg),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = OmniaIcons.Chat,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = stringResource(R.string.chat_empty_title),
            modifier = Modifier.padding(top = OmniaSpacing.md),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.chat_empty_body),
            modifier = Modifier.padding(top = OmniaSpacing.xs),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
fun ChatRoute(
    dependencies: ChatDependencies,
    onOpenProviders: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val viewModel: ChatViewModel = viewModel { ChatViewModel(dependencies) }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ChatScreen(
        uiState = uiState,
        onOpenProviders = onOpenProviders,
        onOpenSettings = onOpenSettings,
        modifier = modifier,
    )
}
