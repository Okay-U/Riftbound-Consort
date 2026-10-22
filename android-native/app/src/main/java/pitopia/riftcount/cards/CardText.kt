package pitopia.riftcount.cards

/**
 * Card ability text, parsed like iOS `CardTextBlock`: the gallery's HTML (paragraphs, line breaks, bullet
 * lists) with Riot's `:rb_*:` symbol tokens and bracket codes. [Keywords] stay keywords, `[>]` is the arrow.
 */
data class TextBlock(val bullet: Boolean, val runs: List<Run>) {
    sealed interface Run {
        data class Plain(val text: String) : Run
        data class Keyword(val text: String) : Run
        /** A glyph by its drawable name (`rb_might`, `rune_fury`, ...). */
        data class Symbol(val asset: String) : Run
        data object Arrow : Run
    }
}

object CardText {
    private val token = Regex(""":rb_([a-z0-9_]+):|\[([^\]]+)\]""")

    fun asset(token: String): String? = when (token) {
        "might" -> "rb_might"
        "exhaust" -> "rb_exhaust"
        "rune_rainbow" -> "rb_rune_rainbow"
        "rune_fury", "rune_calm", "rune_mind", "rune_body", "rune_order", "rune_chaos" -> token
        "colorless" -> "rb_colorless"
        else -> token.removePrefix("energy_").toIntOrNull()?.takeIf { token.startsWith("energy_") && it in 0..12 }?.let { "rb_energy_$it" }
    }

    /** Errata articles and alt text: `[A]` any rune, `[C]` the card's own rune, `[E]` exhaust, `[M]`/`[S]` might, `[3]` energy. */
    fun assetForCode(code: String, domain: String?): String? = when (code) {
        "A" -> "rb_rune_rainbow"
        "E" -> "rb_exhaust"
        "M", "S" -> "rb_might"
        "C" -> domain?.lowercase()?.takeIf { it in CardFilters.domainsInOrder.map(String::lowercase) }?.let { "rune_$it" } ?: "rb_rune_rainbow"
        else -> code.toIntOrNull()?.takeIf { it in 0..12 }?.let { "rb_energy_$it" }
    }

    fun parse(html: String, domain: String? = null): List<TextBlock> {
        val blocks = mutableListOf<TextBlock>()
        var current = mutableListOf<TextBlock.Run>()
        var bullet = false
        fun flush() {
            val trimmed = trim(current)
            if (trimmed.isNotEmpty()) blocks += TextBlock(bullet, trimmed)
            current = mutableListOf()
        }
        var rest = html
        while (true) {
            val open = rest.indexOf('<')
            val close = if (open >= 0) rest.indexOf('>', open) else -1
            if (open < 0 || close < 0) break
            append(rest.substring(0, open), domain, current)
            val tag = rest.substring(open + 1, close).lowercase()
            rest = rest.substring(close + 1)
            when (tag) {
                "br", "br/", "br /" -> current += TextBlock.Run.Plain("\n")
                "p", "ul", "/p", "/ul" -> { flush(); bullet = false }
                "li" -> { flush(); bullet = true }
                "/li" -> { flush(); bullet = false }
            }
        }
        append(rest, domain, current)
        flush()
        return blocks
    }

    private fun append(raw: String, domain: String?, runs: MutableList<TextBlock.Run>) {
        if (raw.isEmpty()) return
        val text = raw.replace("&gt;", ">").replace("&lt;", "<").replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'")
        var cursor = 0
        for (m in token.findAll(text)) {
            if (m.range.first > cursor) runs += TextBlock.Run.Plain(text.substring(cursor, m.range.first))
            val symbol = m.groups[1]?.value
            if (symbol != null) {
                runs += asset(symbol)?.let { TextBlock.Run.Symbol(it) } ?: TextBlock.Run.Plain(symbol.replace('_', ' '))
            } else {
                when (val code = m.groupValues[2]) {
                    ">" -> runs += TextBlock.Run.Arrow
                    ">>" -> { runs += TextBlock.Run.Arrow; runs += TextBlock.Run.Arrow }
                    "NO TEXT" -> Unit // the gallery's placeholder on preview cards
                    else -> runs += assetForCode(code, domain)?.let { TextBlock.Run.Symbol(it) } ?: TextBlock.Run.Keyword(code)
                }
            }
            cursor = m.range.last + 1
        }
        if (cursor < text.length) runs += TextBlock.Run.Plain(text.substring(cursor))
    }

    private fun trim(runs: List<TextBlock.Run>): List<TextBlock.Run> {
        val out = runs.toMutableList()
        while ((out.firstOrNull() as? TextBlock.Run.Plain)?.text?.isBlank() == true) out.removeAt(0)
        while ((out.lastOrNull() as? TextBlock.Run.Plain)?.text?.isBlank() == true) out.removeAt(out.lastIndex)
        (out.firstOrNull() as? TextBlock.Run.Plain)?.let { out[0] = TextBlock.Run.Plain(it.text.trimStart('\n')) }
        (out.lastOrNull() as? TextBlock.Run.Plain)?.let { out[out.lastIndex] = TextBlock.Run.Plain(it.text.trimEnd('\n')) }
        return out
    }
}
