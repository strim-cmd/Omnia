package com.omnia.designsystem.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** Elevated surface container used for cards and grouped rows. */
@Composable
fun OmniaCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    if (onClick != null) {
        ElevatedCard(onClick = onClick, modifier = modifier) { content() }
    } else {
        ElevatedCard(modifier = modifier) { content() }
    }
}
