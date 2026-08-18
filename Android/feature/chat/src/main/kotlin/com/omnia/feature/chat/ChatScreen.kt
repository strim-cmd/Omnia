package com.omnia.feature.chat

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderModelSelection
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaCard
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun ChatRoute(
    dependencies: ChatDependencies,
    generationCoordinator: ConversationGenerationCoordinator,
    onOpenProviders: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val viewModel: ChatViewModel = viewModel {
        ChatViewModel(dependencies, generationCoordinator)
    }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    ChatScreen(
        uiState = uiState,
        onOpenProviders = onOpenProviders,
        onOpenSettings = onOpenSettings,
        onBack = viewModel::backToList,
        onCreateConversation = viewModel::createConversation,
        onOpenConversation = viewModel::openConversation,
        onStartRename = viewModel::startRename,
        onUpdateComposerText = viewModel::updateComposerText,
        onSendMessage = viewModel::sendMessage,
        onStopGeneration = viewModel::stopGeneration,
        onRetryGeneration = viewModel::retryGeneration,
        onContinueGeneration = viewModel::continueGeneration,
        onSelectModel = viewModel::selectModel,
        onSearchQueryChanged = viewModel::startSearch,
        onClearSearch = viewModel::clearSearch,
        onDismissError = viewModel::dismissError,
        onUpdateRenameText = viewModel::updateRenameText,
        onConfirmRename = viewModel::confirmRename,
        onDismissRename = viewModel::dismissRename,
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    uiState: ChatUiState,
    onOpenProviders: () -> Unit,
    onOpenSettings: () -> Unit,
    onBack: () -> Unit,
    onCreateConversation: () -> Unit,
    onOpenConversation: (ConversationIdentity) -> Unit,
    onStartRename: () -> Unit,
    onUpdateComposerText: (String) -> Unit,
    onSendMessage: () -> Unit,
    onStopGeneration: () -> Unit,
    onRetryGeneration: () -> Unit,
    onContinueGeneration: () -> Unit,
    onSelectModel: (ProviderModelSelection) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onClearSearch: () -> Unit,
    onDismissError: () -> Unit,
    onUpdateRenameText: (String) -> Unit,
    onConfirmRename: () -> Unit,
    onDismissRename: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
        ) { innerPadding ->
            if (uiState.activeConversation == null) {
                ConversationListContent(
                    uiState = uiState,
                    onCreateConversation = onCreateConversation,
                    onOpenConversation = onOpenConversation,
                    onSearchQueryChanged = onSearchQueryChanged,
                    onClearSearch = onClearSearch,
                    onOpenProviders = onOpenProviders,
                    onOpenSettings = onOpenSettings,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                )
            } else {
                ChatContent(
                    uiState = uiState,
                    onBack = onBack,
                    onOpenSettings = onOpenSettings,
                    onStartRename = onStartRename,
                    onUpdateComposerText = onUpdateComposerText,
                    onSendMessage = onSendMessage,
                    onStopGeneration = onStopGeneration,
                    onRetryGeneration = onRetryGeneration,
                    onContinueGeneration = onContinueGeneration,
                    onSelectModel = onSelectModel,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                )
            }
        }
    }

    if (uiState.isRenaming) {
        RenameDialog(
            text = uiState.renameText,
            onTextChange = onUpdateRenameText,
            onConfirm = onConfirmRename,
            onDismiss = onDismissRename,
        )
    }

    uiState.error?.let { error ->
        AlertDialog(
            onDismissRequest = onDismissError,
            confirmButton = {
                TextButton(onClick = onDismissError) {
                    Text(text = stringResource(R.string.chat_error_dismiss))
                }
            },
            title = { Text(text = stringResource(R.string.chat_title)) },
            text = { Text(text = error) },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationListContent(
    uiState: ChatUiState,
    onCreateConversation: () -> Unit,
    onOpenConversation: (ConversationIdentity) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onClearSearch: () -> Unit,
    onOpenProviders: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var searchActive by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(text = stringResource(R.string.chat_title)) },
                actions = {
                    OmniaIconButton(
                        icon = OmniaIcons.Chat,
                        contentDescription = stringResource(R.string.chat_search_placeholder),
                        onClick = { searchActive = !searchActive },
                    )
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
        floatingActionButton = {
            FloatingActionButton(
                onClick = onCreateConversation,
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ) {
                Icon(
                    imageVector = OmniaIcons.Add,
                    contentDescription = stringResource(R.string.chat_new_conversation),
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            AnimatedVisibility(
                visible = searchActive,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                OutlinedTextField(
                    value = uiState.searchQuery,
                    onValueChange = { query ->
                        onSearchQueryChanged(query)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.xs),
                    placeholder = {
                        Text(text = stringResource(R.string.chat_search_placeholder))
                    },
                    singleLine = true,
                    leadingIcon = {
                        OmniaIconButton(
                            icon = OmniaIcons.ArrowBack,
                            contentDescription = stringResource(R.string.chat_back),
                            onClick = {
                                searchActive = false
                                onClearSearch()
                            },
                        )
                    },
                    trailingIcon = {
                        if (uiState.searchQuery.isNotEmpty()) {
                            OmniaIconButton(
                                icon = OmniaIcons.Add,
                                contentDescription = stringResource(R.string.chat_error_dismiss),
                                onClick = {
                                    onSearchQueryChanged("")
                                },
                            )
                        }
                    },
                )
            }

            val displayItems = if (uiState.isSearching) uiState.searchResults else uiState.conversations

            if (displayItems.isEmpty()) {
                ChatEmptyState(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(OmniaSpacing.lg),
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = OmniaSpacing.xs),
                ) {
                    items(
                        items = displayItems,
                        key = { it.id },
                    ) { item ->
                        ConversationListItem(
                            item = item,
                            onClick = {
                                onOpenConversation(ConversationIdentity(item.id))
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ConversationListItem(
    item: ChatUiState.ConversationListItem,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OmniaCard(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.xs),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(OmniaSpacing.md),
        ) {
            Text(
                text = item.title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (item.lastMessage.isNotEmpty()) {
                Spacer(modifier = Modifier.height(OmniaSpacing.xs))
                Text(
                    text = item.lastMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (item.updatedAt > 0) {
                Spacer(modifier = Modifier.height(OmniaSpacing.xs))
                Text(
                    text = formatTimestamp(item.updatedAt),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.outline,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatContent(
    uiState: ChatUiState,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit,
    onStartRename: () -> Unit,
    onUpdateComposerText: (String) -> Unit,
    onSendMessage: () -> Unit,
    onStopGeneration: () -> Unit,
    onRetryGeneration: () -> Unit,
    onContinueGeneration: () -> Unit,
    onSelectModel: (ProviderModelSelection) -> Unit,
    modifier: Modifier = Modifier,
) {
    val listState = rememberLazyListState()
    var showModelSelector by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.messages.size, uiState.partialContent) {
        if (uiState.messages.isNotEmpty() || uiState.partialContent != null) {
            val lastIndex = uiState.messages.size +
                if (uiState.partialContent != null) 1 else 0
            listState.animateScrollToItem(maxOf(0, lastIndex - 1))
        }
    }

    Scaffold(
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(end = OmniaSpacing.sm),
                    ) {
                        Text(
                            text = uiState.title,
                            style = MaterialTheme.typography.titleMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (uiState.currentModel != null) {
                            Text(
                                text = uiState.currentModel.model.name,
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                navigationIcon = {
                    OmniaIconButton(
                        icon = OmniaIcons.ArrowBack,
                        contentDescription = stringResource(R.string.chat_back),
                        onClick = onBack,
                    )
                },
                actions = {
                    OmniaIconButton(
                        icon = OmniaIcons.Settings,
                        contentDescription = stringResource(R.string.chat_rename),
                        onClick = onStartRename,
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                state = listState,
                contentPadding = PaddingValues(vertical = OmniaSpacing.sm),
            ) {
                items(
                    items = uiState.messages,
                    key = { "${it.role}-${it.content.hashCode()}" },
                ) { message ->
                    MessageBubble(
                        content = message.content,
                        isUser = message.role == com.omnia.domain.MessageRole.user,
                        isStreaming = false,
                    )
                }

                if (uiState.partialContent != null && uiState.partialContent.isNotEmpty()) {
                    item(key = "streaming-partial") {
                        MessageBubble(
                            content = uiState.partialContent,
                            isUser = false,
                            isStreaming = true,
                        )
                    }
                }

                if (uiState.isStreaming && uiState.partialContent == null) {
                    item(key = "streaming-indicator") {
                        StreamingLoadingIndicator()
                    }
                }
            }

            if (uiState.isInterrupted) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.xs),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    com.omnia.designsystem.components.OmniaOutlinedButton(
                        text = stringResource(R.string.chat_continue),
                        onClick = onContinueGeneration,
                    )
                }
            }

            ComposerBar(
                text = uiState.composerText,
                isEnabled = uiState.isComposerEnabled && !uiState.isStreaming,
                isStreaming = uiState.isStreaming,
                onTextChange = onUpdateComposerText,
                onSend = onSendMessage,
                onStop = onStopGeneration,
                onRetry = if (uiState.error != null && !uiState.isStreaming) onRetryGeneration else null,
            )
        }
    }

    if (showModelSelector) {
        ModelSelectorDialog(
            models = uiState.availableModels,
            currentModel = uiState.currentModel,
            onSelect = { selection ->
                onSelectModel(selection)
                showModelSelector = false
            },
            onDismiss = { showModelSelector = false },
        )
    }
}

@Composable
private fun ComposerBar(
    text: String,
    isEnabled: Boolean,
    isStreaming: Boolean,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    onRetry: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .imePadding()
            .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.sm),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
    ) {
        if (onRetry != null) {
            com.omnia.designsystem.components.OmniaOutlinedButton(
                text = stringResource(R.string.chat_retry),
                onClick = onRetry,
            )
        }

        TextField(
            value = text,
            onValueChange = onTextChange,
            modifier = Modifier.weight(1f),
            placeholder = {
                Text(text = stringResource(R.string.chat_composer_hint))
            },
            enabled = isEnabled,
            maxLines = 5,
        )

        if (isStreaming) {
            com.omnia.designsystem.components.OmniaButton(
                text = stringResource(R.string.chat_stop),
                onClick = onStop,
            )
        } else {
            com.omnia.designsystem.components.OmniaButton(
                text = stringResource(R.string.chat_send),
                onClick = onSend,
                enabled = text.isNotBlank() && isEnabled,
            )
        }
    }
}

@Composable
private fun StreamingLoadingIndicator(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.sm),
        horizontalArrangement = Arrangement.Start,
    ) {
        Text(
            text = stringResource(R.string.chat_streaming_indicator),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RenameDialog(
    text: String,
    onTextChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(text = stringResource(R.string.chat_rename_confirm))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(text = stringResource(R.string.chat_rename_cancel))
            }
        },
        title = { Text(text = stringResource(R.string.chat_rename_title)) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    )
}

@Composable
private fun ModelSelectorDialog(
    models: List<ModelReference>,
    currentModel: ProviderModelSelection?,
    onSelect: (ProviderModelSelection) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {},
        title = { Text(text = stringResource(R.string.chat_model_selector)) },
        text = {
            LazyColumn {
                items(models) { model ->
                    val isSelected = currentModel?.model?.name == model.name
                    TextButton(
                        onClick = {
                            onSelect(
                                ProviderModelSelection(
                                    provider = currentModel?.provider
                                        ?: com.omnia.domain.ProviderIdentity(id = "default"),
                                    model = model,
                                )
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = model.name,
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            },
                        )
                    }
                }
            }
        },
    )
}

@Composable
private fun ChatEmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
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

private fun formatTimestamp(millis: Long): String {
    if (millis <= 0) return ""
    val now = System.currentTimeMillis()
    val diff = now - millis
    val seconds = diff / 1000
    val minutes = seconds / 60
    val hours = minutes / 60
    val days = hours / 24

    return when {
        minutes < 1 -> "Just now"
        minutes < 60 -> "${minutes}m ago"
        hours < 24 -> "${hours}h ago"
        days < 7 -> "${days}d ago"
        else -> {
            val sdf = SimpleDateFormat("MMM d", Locale.getDefault())
            sdf.format(Date(millis))
        }
    }
}
