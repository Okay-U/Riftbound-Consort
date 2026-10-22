package pitopia.riftcount.ui.common

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
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

/** Icons of the scoreboard seam and dialogs, traced from the mocks. */
object ScoreIcons {
    val Dice = lineIcon("M12 2.5L20.5 7.3v9.4L12 21.5l-8.5-4.8V7.3zM12 7.5L16.5 15h-9z", 19.dp)
    val Undo = lineIcon("M9 14L4 9l5-5M4 9h11a5 5 0 0 1 0 10h-3", 18.dp)
    val Restart = lineIcon("M3 12a9 9 0 1 0 3-6.7M3 4v5h5", 18.dp)
    val Close = lineIcon("M6 6l12 12M18 6L6 18", 17.dp, 2.4f)
    val Arrow = lineIcon("M5 12h14M13 6l6 6-6 6", 22.dp, 2.4f)
    val Check = lineIcon("M4 12l5 5L20 6", 22.dp, 2.6f)
    val Trophy = lineIcon("M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0zM7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3", 19.dp)
}
