package pitopia.riftcount.ui.common

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.graphics.vector.group
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** A line icon from SVG path data on a 24 viewport, stroked white (tint it with a ColorFilter). */
fun lineIcon(pathData: String, size: Dp = 22.dp, stroke: Float = 2f): ImageVector =
    ImageVector.Builder(defaultWidth = size, defaultHeight = size, viewportWidth = 24f, viewportHeight = 24f)
        .addPath(
            pathData = addPathNodes(pathData),
            stroke = SolidColor(Color.White),
            strokeLineWidth = stroke,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
        )
        .build()

private fun dot(x: Float, y: Float, r: Float = 1.05f) = "M${x - r} ${y}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0z"

/** Two dice as thrown: tilted rounded squares with their pips, so "roll" reads at a glance (Okay, 2026-10-22). */
private fun dicePair(size: Dp): ImageVector {
    fun ImageVector.Builder.die(square: String, pips: String) {
        addPath(addPathNodes(square), stroke = SolidColor(Color.White), strokeLineWidth = 1.7f, strokeLineJoin = StrokeJoin.Round)
        addPath(addPathNodes(pips), fill = SolidColor(Color.White))
    }
    return ImageVector.Builder(defaultWidth = size, defaultHeight = size, viewportWidth = 24f, viewportHeight = 24f)
        .group(rotate = -14f, pivotX = 6f, pivotY = 13.5f) {
            die("M3.5 9h5a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2z", dot(4.3f, 11.8f) + dot(7.7f, 15.2f))
        }
        .group(rotate = 12f, pivotX = 17f, pivotY = 9.5f) {
            die("M14.5 5h5a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2z", dot(15f, 7.5f) + dot(17f, 9.5f) + dot(19f, 11.5f))
        }
        .build()
}

/** Icons of the scoreboard seam and dialogs, traced from the mocks. */
object ScoreIcons {
    val Dice = dicePair(21.dp)
    val Undo = lineIcon("M9 14L4 9l5-5M4 9h11a5 5 0 0 1 0 10h-3", 18.dp)
    val Close = lineIcon("M6 6l12 12M18 6L6 18", 17.dp, 2.4f)
    val Arrow = lineIcon("M5 12h14M13 6l6 6-6 6", 22.dp, 2.4f)
    val Check = lineIcon("M4 12l5 5L20 6", 22.dp, 2.6f)
    val Trophy = lineIcon("M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0zM7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3", 19.dp)
}
