package pitopia.riftcount.cards

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em

/**
 * Card text as the mock sets it: one paragraph per line, [Keywords] as soft chips, reminder text in
 * parentheses in italics, Riot's symbols inline at text size.
 */
@Composable
fun RulesText(blocks: List<TextBlock>, style: TextStyle, modifier: Modifier = Modifier, gap: Dp = 10.dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val chipStyle = style.copy(fontWeight = FontWeight.Bold)
    val lines = remember(blocks) { blocks.flatMap(::linesOf) }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(gap)) {
        lines.forEach { (bullet, runs) ->
            val inline = mutableMapOf<String, InlineTextContent>()
            val text = annotate(runs, style) { id, chip ->
                inline.getOrPut(id) {
                    if (chip == null) symbolContent(id.removePrefix("sym:"))
                    else {
                        val w = measurer.measure(chip, chipStyle).size.width + with(density) { 14.dp.toPx() }
                        keywordContent(chip, chipStyle, with(density) { w.toSp() })
                    }
                }
            }
            if (bullet) {
                Row {
                    BasicText("•", Modifier.padding(end = 8.dp), style = style)
                    BasicText(text, style = style, inlineContent = inline)
                }
            } else {
                BasicText(text, style = style, inlineContent = inline)
            }
        }
    }
}

/** A block's runs split at its line breaks; only the first line of a list item carries the bullet. */
private fun linesOf(block: TextBlock): List<Pair<Boolean, List<TextBlock.Run>>> {
    val lines = mutableListOf(mutableListOf<TextBlock.Run>())
    block.runs.forEach { run ->
        val text = (run as? TextBlock.Run.Plain)?.text
        if (text == null || '\n' !in text) {
            lines.last() += run
        } else {
            text.split('\n').forEachIndexed { i, part ->
                if (i > 0) lines += mutableListOf<TextBlock.Run>()
                if (part.isNotEmpty()) lines.last() += TextBlock.Run.Plain(part)
            }
        }
    }
    return lines.map { it.trimBlank() }.filter { it.isNotEmpty() }.mapIndexed { i, runs -> (block.bullet && i == 0) to runs }
}

private fun List<TextBlock.Run>.trimBlank(): List<TextBlock.Run> {
    val out = toMutableList()
    (out.firstOrNull() as? TextBlock.Run.Plain)?.let { out[0] = TextBlock.Run.Plain(it.text.trimStart()) }
    (out.lastOrNull() as? TextBlock.Run.Plain)?.let { out[out.lastIndex] = TextBlock.Run.Plain(it.text.trimEnd()) }
    return out.filterNot { it is TextBlock.Run.Plain && it.text.isEmpty() }
}

/** [inline] registers an inline element by id: a symbol (chip null) or a keyword chip with its label. */
private fun annotate(runs: List<TextBlock.Run>, style: TextStyle, inline: (id: String, chip: String?) -> Unit): AnnotatedString =
    buildAnnotatedString {
        val reminder = SpanStyle(fontStyle = FontStyle.Italic, color = (style.color.takeIf { it != Color.Unspecified } ?: Color.White).copy(alpha = 0.62f))
        var depth = 0
        fun plain(text: String) {
            if (text.isEmpty()) return
            if (depth > 0) withStyle(reminder) { append(text) } else append(text)
        }
        runs.forEach { run ->
            when (run) {
                is TextBlock.Run.Plain -> {
                    val part = StringBuilder()
                    run.text.forEach { ch ->
                        when (ch) {
                            '(' -> { plain(part.toString()); part.clear(); depth++; part.append(ch) }
                            ')' -> { part.append(ch); plain(part.toString()); part.clear(); depth = maxOf(0, depth - 1) }
                            else -> part.append(ch)
                        }
                    }
                    plain(part.toString())
                }
                // Inside reminder text a keyword is just a word, as on the printed card.
                is TextBlock.Run.Keyword -> if (depth > 0) plain(run.text) else {
                    val id = "kw:${run.text}"
                    inline(id, run.text)
                    appendInlineContent(id, run.text)
                }
                is TextBlock.Run.Symbol -> if (CardStyle.symbol(run.asset) == null) plain(run.asset) else {
                    val id = "sym:${run.asset}"
                    inline(id, null)
                    // The placeholder replaces this text on screen; TalkBack reads it, spaced from its neighbours.
                    appendInlineContent(id, " ${CardStyle.symbolLabel(run.asset)} ")
                }
                TextBlock.Run.Arrow -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(" → ") }
            }
        }
    }

private fun symbolContent(asset: String) = InlineTextContent(Placeholder(1.15.em, 1.15.em, PlaceholderVerticalAlign.TextCenter)) {
    CardStyle.symbol(asset)?.let { Image(painterResource(it), null, Modifier.fillMaxSize()) }
}

private fun keywordContent(label: String, style: TextStyle, width: TextUnit) =
    InlineTextContent(Placeholder(width, 1.4.em, PlaceholderVerticalAlign.TextCenter)) {
        Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(7.dp)), contentAlignment = Alignment.Center) {
            BasicText(label, style = style.copy(lineHeight = style.fontSize), maxLines = 1, softWrap = false)
        }
    }
