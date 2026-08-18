package com.omnia.feature.chat

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.omnia.designsystem.foundation.OmniaSpacing

private data class CodeBlock(val language: String, val code: String)

private fun parseContent(content: String): List<Any> {
    val segments = mutableListOf<Any>()
    val regex = Regex("```(\\w*)\\n(.*?)```", RegexOption.DOT_MATCHES_ALL)
    var lastEnd = 0

    for (match in regex.findAll(content)) {
        if (match.range.first > lastEnd) {
            val text = content.substring(lastEnd, match.range.first).trimEnd()
            if (text.isNotEmpty()) segments.add(text)
        }
        val lang = match.groupValues[1].ifEmpty { "code" }
        val code = match.groupValues[2].trimEnd('\n')
        segments.add(CodeBlock(lang, code))
        lastEnd = match.range.last + 1
    }

    if (lastEnd < content.length) {
        val remaining = content.substring(lastEnd).trim()
        if (remaining.isNotEmpty()) segments.add(remaining)
    }

    if (segments.isEmpty() && content.isNotBlank()) {
        segments.add(content.trim())
    }

    return segments
}

private fun copyToClipboard(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = ClipData.newPlainText("message", text)
    clipboard.setPrimaryClip(clip)
    Toast.makeText(context, context.getString(R.string.chat_copy), Toast.LENGTH_SHORT).show()
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    content: String,
    isUser: Boolean,
    isStreaming: Boolean,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val backgroundColor = if (isUser) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = if (isUser) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    val shape = RoundedCornerShape(
        topStart = if (isUser) 16.dp else 4.dp,
        topEnd = if (isUser) 4.dp else 16.dp,
        bottomStart = 16.dp,
        bottomEnd = 16.dp,
    )

    val horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    val rowArrangement = if (isUser) Arrangement.End else Arrangement.Start

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = OmniaSpacing.md, vertical = OmniaSpacing.xs),
        horizontalArrangement = rowArrangement,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(shape)
                .background(backgroundColor)
                .combinedClickable(
                    onClick = {},
                    onLongClick = { copyToClipboard(context, content) },
                )
                .padding(OmniaSpacing.sm),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = horizontalAlignment,
            ) {
                val segments = parseContent(content)
                segments.forEach { segment ->
                    when (segment) {
                        is CodeBlock -> CodeBlockView(
                            code = segment.code,
                            language = segment.language,
                            textColor = textColor,
                        )
                        is String -> Text(
                            text = segment,
                            style = MaterialTheme.typography.bodyMedium,
                            color = textColor,
                        )
                    }
                }
                if (isStreaming) {
                    StreamingIndicator(color = textColor)
                }
            }
        }
    }
}

@Composable
private fun CodeBlockView(
    code: String,
    language: String,
    textColor: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val codeBackgroundColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.5f)

    Column(modifier = modifier.padding(vertical = OmniaSpacing.xs)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(codeBackgroundColor, RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp))
                .padding(horizontal = OmniaSpacing.sm, vertical = OmniaSpacing.xs),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = language,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Button(
                onClick = { copyToClipboard(context, code) },
                modifier = Modifier,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                    contentColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Text(
                    text = stringResource(R.string.chat_copy_code),
                    style = MaterialTheme.typography.labelLarge,
                    fontSize = 12.sp,
                )
            }
        }
        Text(
            text = code,
            modifier = Modifier
                .fillMaxWidth()
                .background(codeBackgroundColor, RoundedCornerShape(bottomStart = 8.dp, bottomEnd = 8.dp))
                .padding(OmniaSpacing.sm),
            style = TextStyle(
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                color = textColor,
            ),
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun StreamingIndicator(color: androidx.compose.ui.graphics.Color) {
    Text(
        text = "\u258C",
        style = MaterialTheme.typography.bodyMedium,
        color = color,
    )
}
