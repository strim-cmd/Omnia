package com.omnia.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp

/** Full-screen background surface behind every destination. */
@Composable
fun OmniaBackground(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        content()
    }
}

/** Grouped-row container: rounded, tinted, subtle border. */
@Composable
fun OmniaGroupSurface(
    modifier: Modifier = Modifier,
    borderWidth: Dp = Dp.Hairline,
    borderColor: Color? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    val colorScheme = MaterialTheme.colorScheme
    val shape = MaterialTheme.shapes.medium
    Box(
        modifier = modifier
            .clip(shape)
            .background(colorScheme.surfaceVariant)
            .border(
                width = borderWidth,
                color = borderColor ?: colorScheme.outlineVariant,
                shape = shape,
            ),
    ) {
        content()
    }
}
