package pitopia.riftcount.score

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import pitopia.riftcount.cards.CardImages

// Legend art on the board (iOS `LegendPicture`, mock "1 · Art under a shade" with the middle "d"): the picture behind
// a half and the shade that keeps its number readable. `LegendArt` names the picture.

private val Reach = 90.dp
private val Fade = 70.dp

/** Darkened to 72 % and a touch more saturated, like the mock's filter. */
private val Darkened = ColorFilter.colorMatrix(
    ColorMatrix().apply {
        setToSaturation(1.05f)
        timesAssign(ColorMatrix().apply { setToScale(0.72f, 0.72f, 0.72f, 1f) })
    },
)

/** The picture behind [url] through the card image caches; null while it loads, when it cannot be fetched or without one. */
@Composable
fun rememberLegendPicture(url: String?): State<ImageBitmap?> = produceState(url?.let(CardImages::cached), url) {
    value = url?.let(CardImages::cached)
    if (url != null && value == null) value = CardImages.load(url)
}

/**
 * One half's picture, fixed to the screen: it hangs from the board's middle and reaches 90dp past it with a 70dp fade,
 * and the territory line ([line], read while drawing) cuts it, so the leader uncovers more of theirs. The far half's
 * is turned round for the player across. [middle] and [line] count from the top of the screen.
 */
@Composable
fun LegendPicture(image: ImageBitmap?, turned: Boolean, middle: Dp, line: () -> Dp, screen: Dp) {
    val shown by animateFloatAsState(if (image != null) 1f else 0f, tween(600), label = "legendArt")
    if (image == null) return
    // Both halves the same height, so both pictures sit at the same scale.
    val box = maxOf(middle, screen - middle) + Reach
    val top = if (turned) middle + Reach - box else middle - Reach
    Image(
        image, contentDescription = null, contentScale = ContentScale.Crop, colorFilter = Darkened,
        modifier = Modifier.fillMaxWidth().height(box)
            .offset { IntOffset(0, top.roundToPx()) }
            .graphicsLayer { alpha = shown; compositingStrategy = CompositingStrategy.Offscreen }
            .drawWithContent {
                val cut = (line() - top).toPx()
                val soft = Fade.toPx() / size.height
                // The far picture shows above the line, yours below it; the side past the middle fades out.
                clipRect(top = if (turned) 0f else cut, bottom = if (turned) cut else size.height) {
                    this@drawWithContent.drawContent()
                    val fade = if (turned) arrayOf(1f - soft to Color.Black, 1f to Color.Transparent) else arrayOf(0f to Color.Transparent, soft to Color.Black)
                    drawRect(Brush.verticalGradient(*fade), blendMode = BlendMode.DstIn)
                }
            }
            .graphicsLayer { rotationZ = if (turned) 180f else 0f },
    )
}

/**
 * Behind an art half's number: the mock's dark radial shade, an ellipse 75 % of the width and half the height across,
 * at [alpha] while it fades in. [extend]: how far (px) the half's field runs on past its outer edge (under the tab
 * bar); the shade's rim runs on with it, or its edge shows as a stripe.
 */
fun DrawScope.legendShade(alpha: Float, extend: Float = 0f) {
    val center = Offset(size.width / 2, size.height * 0.46f)
    val radius = size.height * 0.5f
    clipRect {
        scale(scaleX = size.width * 0.75f / radius, scaleY = 1f, pivot = center) {
            drawRect(
                Brush.radialGradient(
                    0f to Color.Black.copy(alpha = 0.55f * alpha),
                    0.72f to Color.Black.copy(alpha = 0.12f * alpha),
                    1f to Color.Black.copy(alpha = 0.35f * alpha),
                    center = center, radius = radius,
                ),
                topLeft = Offset(-size.width, -size.height), size = Size(size.width * 3, size.height * 3),
            )
        }
    }
    if (extend > 0f) drawRect(Color.Black.copy(alpha = 0.35f * alpha), topLeft = Offset(0f, size.height), size = Size(size.width, extend))
}
