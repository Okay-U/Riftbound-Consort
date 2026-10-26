package pitopia.riftcount.cards

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

/** Card proportions of the grid tile (120 × 168 in the mock). */
const val CARD_ASPECT = 120f / 168f
private val TileShape = RoundedCornerShape(10.dp)
private val EmblemAlignment = BiasAlignment(0f, -0.21f)

/**
 * A card as the grid shows it: Riot's card in the mock's frame, bare like the Skip app's grid (Okay, 2026-10-26:
 * the shade with name and type line covered it), ERRATA / PREVIEW stamps in its corner. [labels] fades the
 * stamps out (the detail hero).
 */
@Composable
fun CardFace(card: Card, errata: Boolean, art: ImageBitmap?, modifier: Modifier = Modifier, labels: () -> Float = { 1f }) {
    Box(modifier.clip(TileShape).background(Color(0xFF0B0B0B))) {
        if (art != null) {
            CardArt(art, landscape = card.orientation.equals("landscape", true))
        } else {
            Box(Modifier.fillMaxSize().placeholderArt(card))
            val domain = CardStyle.domains(card).firstOrNull()
            Image(
                painterResource(CardStyle.glyph(domain)), null,
                Modifier.align(EmblemAlignment).fillMaxWidth(0.53f).aspectRatio(1f).graphicsLayer { alpha = 0.38f },
                colorFilter = ColorFilter.tint(CardStyle.domainColor(domain)),
            )
            // A card without any art (one the feed no longer has, in a deck) names itself on it.
            if (card.media?.imageUrl == null) {
                BasicText(
                    card.name,
                    Modifier.align(Alignment.BottomStart).padding(8.dp),
                    style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 13.4.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.9f)),
                    maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (errata || card.isPreview) {
            Row(
                Modifier.align(Alignment.BottomStart).padding(6.dp).graphicsLayer { alpha = labels() },
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (errata) Stamp("ERRATA", RiftColors.Gold)
                if (card.isPreview) Stamp("PREVIEW", Color.White)
            }
        }
        Box(Modifier.matchParentSize().border(1.dp, Color.White.copy(alpha = 0.14f), TileShape))
    }
}

/** Riot's art; battlefields are landscape and turn -90° to fill the portrait frame (as iOS does). */
@Composable
private fun CardArt(art: ImageBitmap, landscape: Boolean) {
    if (!landscape) {
        Image(art, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        return
    }
    Image(
        art, null,
        Modifier.fillMaxSize()
            .layout { measurable, constraints ->
                val turned = measurable.measure(Constraints.fixed(constraints.maxHeight, constraints.maxWidth))
                layout(constraints.maxWidth, constraints.maxHeight) {
                    turned.place((constraints.maxWidth - turned.width) / 2, (constraints.maxHeight - turned.height) / 2)
                }
            }
            .rotate(-90f),
        contentScale = ContentScale.Crop,
    )
}

/** The rarity mark: a small square on its corner. */
@Composable
fun Gem(color: Color, size: Dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size).rotate(45f).background(color))
}

@Composable
private fun Stamp(text: String, ink: Color, size: TextUnit = 7.5.sp) {
    BasicText(
        text,
        // Dark under the tint: the stamp sits on the bare card.
        Modifier.background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(3.dp)).background(ink.copy(alpha = 0.2f), RoundedCornerShape(3.dp))
            .padding(horizontal = 4.dp, vertical = 1.dp),
        style = RiftType.Caption.copy(fontSize = size, fontWeight = FontWeight.Bold, letterSpacing = 0.1.em, color = ink),
        maxLines = 1, softWrap = false,
    )
}
