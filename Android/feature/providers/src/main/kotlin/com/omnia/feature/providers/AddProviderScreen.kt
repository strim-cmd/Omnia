package com.omnia.feature.providers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaButton
import com.omnia.designsystem.components.OmniaGroupSurface
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons
import com.omnia.domain.ProviderAPIKind

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddProviderScreen(
    uiState: AddProviderUiState,
    onBack: () -> Unit,
    onDisplayNameChanged: (String) -> Unit,
    onEndpointChanged: (String) -> Unit,
    onApiKeyChanged: (String) -> Unit,
    onApiKindChanged: (ProviderAPIKind) -> Unit,
    onTestConnection: () -> Unit,
    onSelectedModelChanged: (String) -> Unit,
    onSaveProvider: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isSaveEnabled = if (uiState.isEditing) {
        uiState.displayName.isNotBlank() &&
            uiState.endpoint.isNotBlank() &&
            uiState.selectedModel.isNotBlank() &&
            !uiState.isSaving
    } else {
        uiState.isSaveEnabled
    }

    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = if (uiState.isEditing) {
                                stringResource(R.string.providers_edit_title)
                            } else {
                                stringResource(R.string.providers_add_title)
                            },
                        )
                    },
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
                    .padding(innerPadding)
                    .padding(OmniaSpacing.md)
                    .verticalScroll(rememberScrollState()),
            ) {
                SectionLabel(text = stringResource(R.string.providers_display_name))
                TextField(
                    value = uiState.displayName,
                    onValueChange = onDisplayNameChanged,
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    placeholder = { Text(stringResource(R.string.providers_display_name)) },
                    colors = TextFieldDefaults.colors(
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    ),
                )

                Spacer(modifier = Modifier.height(OmniaSpacing.md))

                SectionLabel(text = stringResource(R.string.providers_endpoint))
                TextField(
                    value = uiState.endpoint,
                    onValueChange = onEndpointChanged,
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    placeholder = { Text(stringResource(R.string.providers_endpoint_placeholder)) },
                    colors = TextFieldDefaults.colors(
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    ),
                )

                Spacer(modifier = Modifier.height(OmniaSpacing.md))

                SectionLabel(text = stringResource(R.string.providers_api_key))
                TextField(
                    value = uiState.apiKey,
                    onValueChange = onApiKeyChanged,
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    colors = TextFieldDefaults.colors(
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    ),
                )

                Spacer(modifier = Modifier.height(OmniaSpacing.md))

                SectionLabel(text = stringResource(R.string.providers_api_kind))
                OmniaGroupSurface(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(OmniaSpacing.sm)) {
                        ApiKindOption(
                            label = stringResource(R.string.providers_openai_compatible),
                            selected = uiState.apiKind == ProviderAPIKind.openAICompatible,
                            onClick = { onApiKindChanged(ProviderAPIKind.openAICompatible) },
                        )
                        ApiKindOption(
                            label = stringResource(R.string.providers_gemini),
                            selected = uiState.apiKind == ProviderAPIKind.gemini,
                            onClick = { onApiKindChanged(ProviderAPIKind.gemini) },
                        )
                    }
                }

                Spacer(modifier = Modifier.height(OmniaSpacing.lg))

                OmniaButton(
                    text = if (uiState.isTesting) {
                        stringResource(R.string.providers_testing)
                    } else {
                        stringResource(R.string.providers_test_connection)
                    },
                    onClick = onTestConnection,
                    enabled = uiState.isTestEnabled,
                    modifier = Modifier.fillMaxWidth(),
                )

                if (uiState.isTesting) {
                    Spacer(modifier = Modifier.height(OmniaSpacing.sm))
                    CircularProgressIndicator(
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .size(24.dp),
                        strokeWidth = 2.dp,
                    )
                }

                when (val result = uiState.testResult) {
                    is AddProviderUiState.TestResult.Success -> {
                        Spacer(modifier = Modifier.height(OmniaSpacing.sm))
                        Text(
                            text = stringResource(
                                R.string.providers_test_success,
                                result.models.size,
                            ),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                    is AddProviderUiState.TestResult.Failure -> {
                        Spacer(modifier = Modifier.height(OmniaSpacing.sm))
                        Text(
                            text = result.message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                    null -> { /* no result yet */ }
                }

                if (uiState.discoveredModels.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(OmniaSpacing.lg))
                    SectionLabel(text = stringResource(R.string.providers_select_model))
                    OmniaGroupSurface(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(OmniaSpacing.sm)) {
                            for (model in uiState.discoveredModels) {
                                ModelOption(
                                    name = model.name,
                                    selected = model.name == uiState.selectedModel,
                                    onClick = { onSelectedModelChanged(model.name) },
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(OmniaSpacing.lg))

                OmniaButton(
                    text = stringResource(R.string.providers_save),
                    onClick = onSaveProvider,
                    enabled = isSaveEnabled,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier.padding(bottom = OmniaSpacing.xs),
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

@Composable
private fun ApiKindOption(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = OmniaSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
    ) {
        RadioButton(
            selected = selected,
            onClick = onClick,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun ModelOption(
    name: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = OmniaSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(OmniaSpacing.sm),
    ) {
        RadioButton(
            selected = selected,
            onClick = onClick,
        )
        Text(
            text = name,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}
