package pitopia.riftcount.score

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.ui.theme.RiftColors

/** Black on light colours, white on dark ones, for text on a filled button. */
fun inkOn(color: Color): Color = if (color.luminance() > 0.35f) Color.Black else Color.White

/** A player colour: the iOS palette (stored index 0-14) plus Rift Green (15) and Rift Violet (16). */
data class Swatch(val index: Int, val name: String, val color: Color) {
    val ink: Color get() = inkOn(color)
}

object PlayerColors {
    private val ios = listOf(
        "Pastel Red" to 0xFFFF004A, "Pastel Blue" to 0xFF4250FF, "Pastel Yellow" to 0xFFFFC300,
        "Pastel Pink" to 0xFFF897FF, "Pastel Purple" to 0xFF7415FE, "Pastel Green" to 0xFF00D06B,
        "Pastel Orange" to 0xFFFF5100, "Warm Stone" to 0xFF948979, "Dark Ash" to 0xFF37353E,
        "Warm Wood" to 0xFF715A5A, "Crimson" to 0xFF901E3E, "Deep Night" to 0xFF210F37,
        "Berry Wine" to 0xFF511D43, "Indigo Glow" to 0xFF4B4376, "Ember Orange" to 0xFF9B3922,
    ).mapIndexed { i, (name, argb) -> Swatch(i, name, Color(argb)) }

    val RiftGreen = Swatch(15, "Rift Green", RiftColors.You)
    val RiftViolet = Swatch(16, "Rift Violet", RiftColors.Opponent)

    /** The 16 swatches of the Settings mock; Deep Night stays readable for old picks but is not offered. */
    val offered: List<Swatch> = listOf(RiftGreen, RiftViolet) + ios.filter { it.name != "Deep Night" }

    private fun byIndex(i: Int): Swatch? = when (i) {
        15 -> RiftGreen
        16 -> RiftViolet
        else -> ios.getOrNull(i)
    }

    /** Defaults: you green and the opponent violet; with four players blue and yellow join. */
    private fun default(slot: Int, players: Int): Swatch =
        if (players == 2) (if (slot == YOU) RiftGreen else RiftViolet)
        else listOf(RiftViolet, ios[1], RiftGreen, ios[2])[slot]

    fun forSlot(slot: Int, players: Int): Swatch = resolve(List(players) { byIndex(Prefs.int("colorIdx_$it", -1)) }, players)[slot]

    /**
     * Saved picks stay; a seat without one takes its default, or, when a pick has that, a default left free
     * and then the first free colour (2 and 4 players share the keys: "You" in green meets seat 3's green).
     */
    internal fun resolve(picked: List<Swatch?>, players: Int): List<Swatch> {
        val taken = picked.mapNotNullTo(HashSet()) { it?.index }
        val spare = List(players) { default(it, players) } + offered
        return picked.mapIndexed { slot, pick ->
            pick ?: default(slot, players).let { d -> if (d.index in taken) spare.first { it.index !in taken } else d }.also { taken += it.index }
        }
    }
}
