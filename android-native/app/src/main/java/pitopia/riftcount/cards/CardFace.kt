package pitopia.riftcount.cards

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.ui.graphics.Brush
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
 * A card as the grid shows it: Riot's art in the mock's frame, a shade with the name and a type line
 * (rarity gem, kind, ERRATA / PREVIEW stamps). [labels] fades the frame out over the art (the detail hero).
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
        }
        Box(Modifier.fillMaxSize().graphicsLayer { alpha = labels() }) {
            Box(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().fillMaxHeight(0.64f).background(
                    Brush.verticalGradient(0f to Color.Transparent, 0.54f to Color.Black.copy(alpha = 0.62f), 1f to Color.Black.copy(alpha = 0.94f)),
                ),
            )
            BasicText(
                card.name,
                Modifier.align(Alignment.BottomStart).padding(start = 8.dp, end = 8.dp, bottom = 22.dp),
                style = RiftType.Body.copy(fontSize = 12.sp, lineHeight = 13.4.sp, fontWeight = FontWeight.Bold, color = Color.White),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Row(
                Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(start = 8.dp, end = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Gem(CardStyle.rarityColor(card.rarity), 6.dp)
                BasicText(
                    CardStyle.kind(card).uppercase(), Modifier.weight(1f),
                    style = RiftType.Caption.copy(fontSize = 8.5.sp, letterSpacing = 0.12.em, color = Color.White.copy(alpha = 0.66f)),
                    maxLines = 1, softWrap = false, overflow = TextOverflow.Clip,
                )
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
        Modifier.background(ink.copy(alpha = 0.2f), RoundedCornerShape(3.dp)).padding(horizontal = 4.dp, vertical = 1.dp),
        style = RiftType.Caption.copy(fontSize = size, fontWeight = FontWeight.Bold, letterSpacing = 0.1.em, color = ink),
        maxLines = 1, softWrap = false,
    )
}
