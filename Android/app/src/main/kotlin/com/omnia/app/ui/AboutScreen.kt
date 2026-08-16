package com.omnia.app.ui

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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.omnia.app.R
import com.omnia.application.AppMetadata
import com.omnia.designsystem.components.OmniaBackground
import com.omnia.designsystem.components.OmniaIconButton
import com.omnia.designsystem.foundation.OmniaSpacing
import com.omnia.designsystem.icon.OmniaIcons

/** About destination: app identity and foundation note. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(
    metadata: AppMetadata,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OmniaBackground(modifier = modifier) {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            topBar = {
                TopAppBar(
                    title = { Text(text = stringResource(R.string.about_title)) },
                    navigationIcon = {
                        OmniaIconButton(
                            icon = OmniaIcons.ArrowBack,
                            contentDescription = stringResource(R.string.about_back),
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
                    .padding(OmniaSpacing.lg),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    imageVector = OmniaIcons.Info,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
                Text(
                    text = metadata.name,
                    modifier = Modifier.padding(top = OmniaSpacing.md),
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResource(R.string.about_version, metadata.versionLabel),
                    modifier = Modifier.padding(top = OmniaSpacing.xs),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = stringResource(R.string.about_foundation_note),
                    modifier = Modifier.padding(top = OmniaSpacing.xs),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}
