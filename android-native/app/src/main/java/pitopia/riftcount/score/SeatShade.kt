package pitopia.riftcount.score

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.colorspace.ColorSpaces
import kotlin.math.cbrt

/**
 * Colour model C, the board's look (iOS `SeatShade`, docs/IOS_REDESIGN.md "Score tile look"): each field is its seat
 * colour brought to one depth, so every seat reads alike under white text. What the board draws in the seat colour
 * (the line, dice, WIN, badges) is lifted where that colour would not show on its field. SeatShadeTest checks every
 * player colour.
 */
object SeatShade {
    /** OKLab lightness of a field: white is 7:1 or more on every player colour. */
    const val FIELD = 0.44f

    /** The seat colour on the board is at least this light: 3.3:1 or more on its own field. */
    const val LIFTED = 0.74f

    /**
     * [color] at the field's depth times [depth] (1.125 a leading seat, 0.75 Conquer's ink). Linear RGB times k³ is
     * OKLab's L, a and b times k: the hue stays and the chroma falls with the lightness. Colours darker than a field
     * keep their own depth.
     */
    fun deep(color: Color, depth: Float = 1f): Color {
        val c = color.convert(ColorSpaces.LinearSrgb)
        val l = lightness(c.red, c.green, c.blue)
        if (l <= 0f) return color
        val k = minOf(l, FIELD) * depth / l
        val k3 = k * k * k
        return linear(c.red * k3, c.green * k3, c.blue * k3)
    }

    /** [color] mixed with white until it is [LIFTED] light; lighter colours stay as they are. */
    fun lift(color: Color): Color {
        val c = color.convert(ColorSpaces.LinearSrgb)
        val (r, g, b) = Triple(c.red, c.green, c.blue)
        if (lightness(r, g, b) >= LIFTED) return color
        var low = 0f
        var high = 1f
        repeat(16) {
            val t = (low + high) / 2
            if (lightness(r + t * (1 - r), g + t * (1 - g), b + t * (1 - b)) < LIFTED) low = t else high = t
        }
        return linear(r + high * (1 - r), g + high * (1 - g), b + high * (1 - b))
    }

    /** OKLab L of linear sRGB (Björn Ottosson's matrices). */
    fun lightness(r: Float, g: Float, b: Float): Float {
        val l = cbrt(0.4122214708f * r + 0.5363325363f * g + 0.0514459929f * b)
        val m = cbrt(0.2119034982f * r + 0.6806995451f * g + 0.1073969566f * b)
        val s = cbrt(0.0883024619f * r + 0.2817188376f * g + 0.6299787005f * b)
        return 0.2104542553f * l + 0.7936177850f * m - 0.0040720468f * s
    }

    private fun linear(r: Float, g: Float, b: Float): Color =
        Color(r.coerceIn(0f, 1f), g.coerceIn(0f, 1f), b.coerceIn(0f, 1f), 1f, ColorSpaces.LinearSrgb).convert(ColorSpaces.Srgb)
}
