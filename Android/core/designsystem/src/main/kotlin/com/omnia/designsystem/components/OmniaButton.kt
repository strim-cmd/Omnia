package com.omnia.designsystem.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import com.omnia.designsystem.foundation.OmniaSpacing

/** Primary filled button with optional leading icon. */
@Composable
fun OmniaButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    Button(onClick = onClick, modifier = modifier, enabled = enabled) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null)
            Spacer(modifier = Modifier.width(OmniaSpacing.sm))
        }
        Text(
            text = text,
            textAlign = TextAlign.Center,
        )
    }
}

/** Secondary (outlined) button with optional leading icon. */
@Composable
fun OmniaOutlinedButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    androidx.compose.material3.OutlinedButton(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
    ) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null)
            Spacer(modifier = Modifier.width(OmniaSpacing.sm))
        }
        Text(text = text, textAlign = TextAlign.Center)
    }
}

/** Text button with optional leading icon. */
@Composable
fun OmniaTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    androidx.compose.material3.TextButton(onClick = onClick, modifier = modifier, enabled = enabled) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null)
            Spacer(modifier = Modifier.width(OmniaSpacing.sm))
        }
        Text(text = text, textAlign = TextAlign.Center)
    }
}
