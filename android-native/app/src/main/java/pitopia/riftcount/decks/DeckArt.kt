package pitopia.riftcount.decks

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max
import pitopia.riftcount.cards.Card
import pitopia.riftcount.cards.CardStyle
import pitopia.riftcount.cards.rememberCardArt
import pitopia.riftcount.ui.theme.RiftType

/** The mock's legend art: the first domain glows from the top left, the second from the bottom right. */
fun Modifier.legendGlow(domains: List<String>): Modifier = drawWithCache {
    val a = CardStyle.domainColor(domains.getOrNull(0))
    val b = CardStyle.domainColor(domains.getOrNull(1) ?: domains.getOrNull(0))
    val r = max(size.width, size.height) * 1.1f
    val top = Brush.radialGradient(
        0f to a.copy(alpha = 0.9f), 0.4f to a.copy(alpha = 0.33f), 0.7f to Color.Transparent,
        center = Offset(size.width * 0.2f, size.height * 0.1f), radius = r,
    )
    val bottom = Brush.radialGradient(
        0f to b.copy(alpha = 0.85f), 0.45f to b.copy(alpha = 0.25f), 0.75f to Color.Transparent,
        center = Offset(size.width * 0.9f, size.height), radius = r,
    )
    onDrawBehind {
        drawRect(Color(0xFF111111))
        drawRect(top)
        drawRect(bottom)
    }
}

/** Upper part of a card's art (the illustration, below the cost and domain marks) for banners and tiles. */
val ArtTop = BiasAlignment(0f, -0.25f)

/**
 * A card's real art cropped into any frame, or the legend glow with a big initial while it loads or when
 * there is no card (a deck without a legend).
 */
@Composable
fun ArtBox(
    card: Card?,
    widthPx: Int,
    modifier: Modifier = Modifier,
    alignment: Alignment = ArtTop,
    initial: String = card?.title?.take(1).orEmpty(),
    initialSize: TextUnit = 110.sp,
    /** A smaller size that is likely cached already (the pile's), shown until [widthPx] arrives. */
    previewWidthPx: Int? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val art by if (card != null) rememberCardArt(card, widthPx) else NoArt
    val preview by if (card != null && previewWidthPx != null) rememberCardArt(card, previewWidthPx) else NoArt
    Box(modifier) {
        val image = art ?: preview
        if (image != null) {
            Image(image, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop, alignment = alignment)
        } else {
            Box(Modifier.fillMaxSize().legendGlow(card?.domains.orEmpty()))
            if (initial.isNotEmpty()) {
                BasicText(
                    initial.uppercase(),
                    Modifier.align(Alignment.TopEnd).padding(end = 6.dp),
                    style = RiftType.Title.copy(fontSize = initialSize, lineHeight = initialSize, fontWeight = FontWeight.Black, color = Color.Black.copy(alpha = 0.32f)),
                    maxLines = 1,
                )
            }
        }
        content()
    }
}

private val NoArt = mutableStateOf<ImageBitmap?>(null)

/** Bottom shade so white text reads on any art. */
fun Modifier.bottomShade(from: Float = 0.45f): Modifier = drawWithCache {
    val brush = Brush.verticalGradient(from to Color.Transparent, 1f to Color.Black.copy(alpha = 0.88f))
    onDrawBehind { drawRect(brush) }
}
