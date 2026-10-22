package pitopia.riftcount.cards

import androidx.annotation.DrawableRes
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import pitopia.riftcount.R

/** Colours and glyphs of the Cards mock (domain hues, rarity gems). */
object CardStyle {
    private val domainColors = mapOf(
        "fury" to Color(0xFFF2554D), "calm" to Color(0xFF4FD18B), "mind" to Color(0xFF4D8EF7),
        "body" to Color(0xFFF4933B), "chaos" to Color(0xFFB06BF2), "order" to Color(0xFFF2C94C),
    )
    val Colorless = Color(0xFFC9CDD2)

    fun domainColor(domain: String?): Color = domain?.let { domainColors[it.lowercase()] } ?: Colorless

    fun rarityColor(rarity: String): Color = when (rarity.lowercase()) {
        "uncommon" -> Color(0xFF5FD3C6)
        "rare" -> Color(0xFF6FA8FF)
        "epic" -> Color(0xFFC08BFF)
        "showcase" -> Color(0xFFF2C94C)
        else -> Color(0xFF9AA0A6)
    }

    /** Riot's rune shape for a domain, white (tint it); colourless gets the colourless mark. */
    @DrawableRes
    fun glyph(domain: String?): Int = when (domain?.lowercase()) {
        "fury" -> R.drawable.rune_fury_glyph
        "calm" -> R.drawable.rune_calm_glyph
        "mind" -> R.drawable.rune_mind_glyph
        "body" -> R.drawable.rune_body_glyph
        "chaos" -> R.drawable.rune_chaos_glyph
        "order" -> R.drawable.rune_order_glyph
        else -> R.drawable.rb_colorless
    }

    private val energy = listOf(
        R.drawable.rb_energy_0, R.drawable.rb_energy_1, R.drawable.rb_energy_2, R.drawable.rb_energy_3, R.drawable.rb_energy_4,
        R.drawable.rb_energy_5, R.drawable.rb_energy_6, R.drawable.rb_energy_7, R.drawable.rb_energy_8, R.drawable.rb_energy_9,
        R.drawable.rb_energy_10, R.drawable.rb_energy_11, R.drawable.rb_energy_12,
    )

    /** Drawable for a [CardText] symbol asset name. */
    @DrawableRes
    fun symbol(asset: String): Int? = when (asset) {
        "rb_might" -> R.drawable.rb_might
        "rb_exhaust" -> R.drawable.rb_exhaust
        "rb_rune_rainbow" -> R.drawable.rb_rune_rainbow
        "rb_colorless" -> R.drawable.rb_colorless
        "rune_fury" -> R.drawable.rune_fury
        "rune_calm" -> R.drawable.rune_calm
        "rune_mind" -> R.drawable.rune_mind
        "rune_body" -> R.drawable.rune_body
        "rune_order" -> R.drawable.rune_order
        "rune_chaos" -> R.drawable.rune_chaos
        else -> asset.removePrefix("rb_energy_").toIntOrNull()?.let { energy.getOrNull(it) }
    }

    /** What TalkBack reads for a symbol: "might", "2 energy", "Fury rune". */
    fun symbolLabel(asset: String): String = when (asset) {
        "rb_might" -> "might"
        "rb_exhaust" -> "exhaust"
        "rb_rune_rainbow" -> "any rune"
        "rb_colorless" -> "colorless"
        else -> asset.removePrefix("rb_energy_").toIntOrNull()?.let { "$it energy" }
            ?: (asset.removePrefix("rune_").replaceFirstChar { it.uppercase() } + " rune")
    }

    /** "Champion" for champion units, else the card type ("Token" when the feed has none). */
    fun kind(card: Card): String = when {
        card.isChampion -> "Champion"
        card.type.isNotEmpty() -> card.type
        card.supertype.isNotEmpty() -> card.supertype
        else -> "Card"
    }

    /** Domains worth showing: the feed writes "Colorless" as one. */
    fun domains(card: Card): List<String> = card.domains.filterNot { it.equals("colorless", true) }
}

/** The mock's stand-in art while the real image loads: two glows in the card's colours on near black. */
fun Modifier.placeholderArt(card: Card): Modifier = drawWithCache {
    var h = 7L
    card.name.forEach { h = (h * 31 + it.code) and 0xFFFFFFFFL }
    val doms = CardStyle.domains(card)
    val a = CardStyle.domainColor(doms.getOrNull(0))
    val b = CardStyle.domainColor(doms.getOrNull(1) ?: doms.getOrNull(0))
    val x = (18 + h % 64) / 100f
    val y = (12 + (h ushr 6) % 40) / 100f
    val x2 = (85 - (h ushr 11) % 60) / 100f
    val angle = Math.toRadians(((h ushr 3) % 360).toDouble())
    val dx = sin(angle).toFloat() * size.width / 2
    val dy = -cos(angle).toFloat() * size.height / 2
    val center = Offset(size.width / 2, size.height / 2)
    val base = Brush.linearGradient(listOf(Color(0xFF1B1B1B), Color(0xFF050505)), center - Offset(dx, dy), center + Offset(dx, dy))
    val glowA = Brush.radialGradient(
        0f to a.copy(alpha = 0.65f), 0.46f to a.copy(alpha = 0.15f), 0.72f to Color.Transparent,
        center = Offset(size.width * x, size.height * y), radius = max(size.width, size.height) * 0.8f,
    )
    val glowB = Brush.radialGradient(
        0f to b.copy(alpha = 0.4f), 0.68f to Color.Transparent,
        center = Offset(size.width * x2, size.height * 0.88f), radius = max(size.width, size.height) * 0.62f,
    )
    onDrawBehind {
        drawRect(base)
        drawRect(glowA)
        drawRect(glowB)
    }
}
