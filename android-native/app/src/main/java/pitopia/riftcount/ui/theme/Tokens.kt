package pitopia.riftcount.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.R
import pitopia.riftcount.data.AppSettings

/** Colours from the chosen mocks: true black, green for you, violet for the opponent. */
object RiftColors {
    val Black = Color(0xFF000000)
    val Ink = Color(0xFFFFFFFF)
    val InkSoft = Color(0xB8FFFFFF)
    val InkMuted = Color(0x99FFFFFF)
    val InkFaint = Color(0x73FFFFFF)
    val You = Color(0xFF2BE38B)
    val Opponent = Color(0xFFA99BFF)
    val Gold = Color(0xFFFFC75E)
    val Danger = Color(0xFFFF6B61)
    val Card = Color(0xFF0D0D0D)
    val Sheet = Color(0xFF101010)
    val Hairline = Color(0x1FFFFFFF)
    val NavBar = Color(0xF00E0E0E)

    /** Page background: true black, or dark grey with the True black switch off. */
    val Page: Color get() = if (AppSettings.trueBlack.on) Black else Color(0xFF121212)
}

/** Exponential ease-out used by every transition in the mocks: cubic-bezier(.16, 1, .3, 1). */
val RiftEase = CubicBezierEasing(0.16f, 1f, 0.3f, 1f)

object RiftType {
    /** Big Shoulders Display (variable, OFL) for numbers and titles. */
    val Display = FontFamily(
        displayWeight(FontWeight.Bold),
        displayWeight(FontWeight.ExtraBold),
        displayWeight(FontWeight.Black),
    )

    /** Barlow (OFL) for everything else. */
    val Text = FontFamily(
        Font(R.font.barlow_regular, FontWeight.Normal),
        Font(R.font.barlow_medium, FontWeight.Medium),
        Font(R.font.barlow_semibold, FontWeight.SemiBold),
        Font(R.font.barlow_bold, FontWeight.Bold),
    )

    val Title = TextStyle(fontFamily = Display, fontWeight = FontWeight.Black, fontSize = 46.sp, lineHeight = 41.sp, letterSpacing = 0.02.em)
    val Body = TextStyle(fontFamily = Text, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 21.sp)
    val NavLabel = TextStyle(fontFamily = Text, fontWeight = FontWeight.SemiBold, fontSize = 10.sp, letterSpacing = 0.06.em)
    val Caption = TextStyle(fontFamily = Text, fontWeight = FontWeight.SemiBold, fontSize = 11.sp, letterSpacing = 0.16.em)

    @OptIn(ExperimentalTextApi::class)
    private fun displayWeight(weight: FontWeight) =
        Font(R.font.big_shoulders_display, weight, variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)))
}
