package pitopia.riftcount.settings

import android.content.ClipData
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import pitopia.riftcount.ui.common.GlowButton
import pitopia.riftcount.ui.common.LinkButton
import pitopia.riftcount.ui.common.Pressable
import pitopia.riftcount.ui.common.Rise
import pitopia.riftcount.ui.theme.RiftColors
import pitopia.riftcount.ui.theme.RiftType

private val FieldLabel = RiftType.Caption.copy(letterSpacing = 0.14.em, color = Color.White.copy(alpha = 0.6f))

/** Report a bug / Wish a feature: a summary and the details, sent through the mail app. */
@Composable
fun FormPage(bug: Boolean, onSend: (subject: String, body: String) -> Unit) {
    var summary by rememberSaveable { mutableStateOf("") }
    var body by rememberSaveable { mutableStateOf("") }
    val context = LocalContext.current
    val details = if (bug) "What happened" else "Describe it"
    Rise(true, 0, Modifier.padding(top = 6.dp)) {
        Column {
            BasicText(
                if (bug) "Tell me what went wrong. Your mail app opens with the report filled in, you can read it before sending."
                else "What would make Riftcount better for you? One idea per wish works best.",
                Modifier.padding(start = 4.dp, end = 4.dp, top = 8.dp),
                style = FootText,
            )
            BasicText("Summary".uppercase(), Modifier.padding(start = 4.dp, top = 18.dp, bottom = 8.dp), style = FieldLabel)
            Field(summary, if (bug) "Score jumped back after undo" else "Show my opponent’s deck after the match", 52.dp, single = true) { summary = it }
            BasicText(details.uppercase(), Modifier.padding(start = 4.dp, top = 18.dp, bottom = 8.dp), style = FieldLabel)
            Field(body, if (bug) "Steps, what you expected, what you saw" else "How would it work, when would you use it?", 180.dp, single = false) { body = it }
            Box(Modifier.padding(top = 12.dp)) {
                GlowButton(if (bug) "Send report" else "Send wish", summary.isNotBlank(), SettingsIcons.Send) {
                    val title = summary.trim()
                    onSend(
                        "${if (bug) "[Bug]" else "[Feature]"} $title",
                        Support.reportBody(if (bug) details else "Description", title, body.trim(), Support.version(context)),
                    )
                }
            }
        }
    }
}

@Composable
private fun Field(value: String, placeholder: String, height: Dp, single: Boolean, onChange: (String) -> Unit) {
    val source = remember { MutableInteractionSource() }
    val focused by source.collectIsFocusedAsState()
    val ring by animateFloatAsState(if (focused) 1f else 0f, tween(250), label = "focus")
    val shape = RoundedCornerShape(18.dp)
    val style = if (single) RiftType.Body.copy(fontSize = 16.sp, lineHeight = 22.sp, color = Color.White)
    else RiftType.Body.copy(fontSize = 15.sp, lineHeight = 22.5.sp, color = Color.White)
    BasicTextField(
        value, onChange,
        Modifier.fillMaxWidth().height(height)
            .drawBehind {
                // focus: 0 0 0 4px rgba(43,227,139,.1)
                if (ring > 0f) {
                    val by = 4.dp.toPx()
                    drawRoundRect(RiftColors.You.copy(alpha = 0.1f * ring), Offset(-by, -by), Size(size.width + 2 * by, size.height + 2 * by), CornerRadius(18.dp.toPx() + by))
                }
            }
            .background(Color(0xFF0B0B0B), shape)
            .border(1.dp, if (ring > 0.5f) RiftColors.You.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.16f), shape),
        textStyle = style,
        singleLine = single,
        cursorBrush = SolidColor(RiftColors.You),
        interactionSource = source,
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Sentences,
            imeAction = if (single) ImeAction.Next else ImeAction.Default,
        ),
        decorationBox = { inner ->
            Box(
                Modifier.padding(horizontal = 16.dp, vertical = if (single) 0.dp else 14.dp),
                contentAlignment = if (single) Alignment.CenterStart else Alignment.TopStart,
            ) {
                if (value.isEmpty()) BasicText(placeholder, style = style.copy(color = Color.White.copy(alpha = 0.4f)))
                inner()
            }
        },
    )
}

private val AckTitle = RiftType.Body.copy(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
private val AckText = RiftType.Body.copy(fontSize = 13.5.sp, lineHeight = 20.25.sp, fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = 0.72f))
private val Mono = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 17.4.sp, color = Color.White.copy(alpha = 0.82f))

@Composable
private fun AckCard(title: String, text: String, delayMs: Int, links: @Composable () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    Rise(true, delayMs, Modifier.padding(top = 10.dp)) {
        Column(
            Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.045f), shape).border(1.dp, Color.White.copy(alpha = 0.08f), shape).padding(16.dp),
        ) {
            BasicText(title, style = AckTitle)
            BasicText(text, Modifier.padding(top = 6.dp, bottom = 2.dp), style = AckText)
            links()
        }
    }
}

@Composable
private fun AckLink(text: String, onClick: () -> Unit) {
    Pressable(onClick, Modifier.padding(vertical = 4.dp), pressedScale = 0.97f) {
        BasicText(text, style = RiftType.Body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = RiftColors.You))
    }
}

/** Acknowledgments (iOS): Riot, the rune icons, and the two OFL fonts with their licence texts. */
@Composable
fun AckPage(onOpen: (String) -> Unit) {
    val context = LocalContext.current
    var license by rememberSaveable { mutableStateOf<String?>(null) }
    AckCard(
        "Riot Games",
        "Card data and images from the official Riftbound card gallery. Riftcount was created under Riot Games' " +
            "\"Legal Jibber Jabber\" policy using assets owned by Riot Games. Riot Games does not endorse or sponsor this project.",
        60,
    ) { AckLink("playriftbound.com") { onOpen("https://playriftbound.com/en-us/card-gallery/") } }
    AckCard("riftboundfaq", "Domain rune icons by Christian Ivicevic, used under CC BY-SA 4.0.", 120) {
        AckLink("github.com/ChristianIvicevic/riftboundfaq") { onOpen("https://github.com/ChristianIvicevic/riftboundfaq") }
        AckLink("CC BY-SA 4.0") { onOpen("https://creativecommons.org/licenses/by-sa/4.0/") }
    }
    AckCard("Fonts", "Big Shoulders Display and Barlow, used under the SIL Open Font License 1.1.", 180) {
        listOf("Big Shoulders Display" to "OFL_big_shoulders_display.txt", "Barlow" to "OFL_barlow.txt").forEach { (name, file) ->
            AckLink(if (license == file) "Hide the $name license" else "$name license") { license = if (license == file) null else file }
            if (license == file) {
                val text = remember(file) { runCatching { context.assets.open("licenses/$file").bufferedReader().use { reflow(it.readText()) } }.getOrDefault("") }
                BasicText(text, Modifier.padding(vertical = 8.dp), style = AckText.copy(fontSize = 12.sp, lineHeight = 17.sp, color = Color.White.copy(alpha = 0.66f)))
            }
        }
    }
    BasicText(
        "Riftbound is a trademark of Riot Games. This app is an unofficial fan project and is not affiliated with Riot Games.",
        Modifier.padding(start = 6.dp, end = 6.dp, top = 16.dp),
        style = FootText,
    )
}

/**
 * The licence files wrap at 72 columns; joined into paragraphs they reflow on any width. Rules of dashes
 * go, headings in capitals keep a line of their own.
 */
internal fun reflow(text: String): String =
    text.lines().filterNot { it.isNotBlank() && it.all { c -> c == '-' } }
        .joinToString("\n") { if (it.isNotBlank() && it.trim().all { c -> c.isUpperCase() || c == ' ' || c == '&' }) "$it\n" else it }
        .split(Regex("\n\\s*\n")).joinToString("\n\n") { it.trim().replace(Regex("\\s*\n\\s*"), " ") }

/** What the app did with PlayRiftbound (iOS `PlayRiftboundLogView`), newest first, with Copy and Clear. */
@Composable
fun LogPage(file: File, onToast: (String) -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()
    val log = remember(file) { PlayRiftboundLog(file) }
    var entries by remember { mutableStateOf<List<LogEntry>?>(null) }
    LaunchedEffect(file) { entries = withContext(Dispatchers.IO) { log.entries() } }
    BasicText(
        "What the app did with PlayRiftbound on this phone. No passwords, cookies or tokens are ever written here.",
        Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
        style = FootText,
    )
    val shown = entries.orEmpty()
    Rise(true, 60) {
        Column(
            Modifier.fillMaxWidth().background(Color(0xFF080808), RoundedCornerShape(22.dp)).border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(22.dp))
                .padding(vertical = 6.dp),
        ) {
            if (entries != null && shown.isEmpty()) LogLine("", "No PlayRiftbound calls logged yet.", null, null, divider = false)
            shown.forEachIndexed { i, e ->
                LogLine(time(e.date), "${e.operation} → ${e.outcome} · ${e.durationMs} ms", e.detail, if (e.ok) RiftColors.You else RiftColors.Gold, divider = i > 0)
            }
        }
    }
    Box(Modifier.padding(top = 14.dp)) {
        GlowButton("Copy log", shown.isNotEmpty()) {
            scope.launch {
                clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("PlayRiftbound log", PlayRiftboundLog.export(shown, Support.version(context)))))
                onToast("Log copied, paste it into a bug report")
            }
        }
    }
    if (shown.isNotEmpty()) {
        Box(Modifier.fillMaxWidth().padding(top = 6.dp), contentAlignment = Alignment.Center) {
            LinkButton("Clear the log", {
                scope.launch {
                    withContext(Dispatchers.IO) { log.clear() }
                    entries = emptyList()
                    onToast("Log cleared")
                }
            }, color = RiftColors.Danger)
        }
    }
}

private fun time(ms: Long): String {
    val day = Calendar.getInstance().apply { timeInMillis = ms }
    val today = Calendar.getInstance()
    val sameDay = day.get(Calendar.YEAR) == today.get(Calendar.YEAR) && day.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
    return SimpleDateFormat(if (sameDay) "HH:mm:ss" else "d MMM HH:mm", Locale.US).format(Date(ms))
}

@Composable
private fun LogLine(time: String, message: String, detail: String?, dot: Color?, divider: Boolean) {
    Row(
        Modifier.fillMaxWidth()
            .drawBehind { if (divider) drawRect(Color.White.copy(alpha = 0.05f), size = Size(size.width, 1.dp.toPx())) }
            .padding(horizontal = 14.dp, vertical = 9.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (time.isNotEmpty()) BasicText(time, style = Mono.copy(color = Color.White.copy(alpha = 0.45f)))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                dot?.let { Box(Modifier.padding(end = 8.dp).size(7.dp).background(it, CircleShape)) }
                BasicText(message, style = Mono)
            }
            detail?.let { BasicText(it, Modifier.padding(top = 2.dp), style = Mono.copy(fontSize = 11.sp, color = Color.White.copy(alpha = 0.55f))) }
        }
    }
}

/** Riot's documents by kind (iOS `RulesView`), each row opening Riot's own page. */
@Composable
fun RulesPage(onOpen: (String) -> Unit) {
    BasicText("Riot's documents open in your browser.", Modifier.padding(start = 4.dp, end = 4.dp, top = 6.dp, bottom = 6.dp), style = FootText)
    RulesLibrary.sections.forEachIndexed { s, section ->
        Rise(true, 60 + s * 70, Modifier.padding(top = if (s == 0) 8.dp else 22.dp)) {
            Column {
                SectionHead(section.title)
                Group {
                    section.links.forEachIndexed { i, link ->
                        LinkRow(link.title, null, link.detail, divider = i > 0, trailing = {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                if (link.pdf) BasicText("PDF", style = RiftType.Caption.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.5f)))
                                Chevron(external = true)
                            }
                        }) { onOpen(link.url) }
                    }
                }
                section.footer?.let { BasicText(it, Modifier.padding(start = 6.dp, end = 6.dp, top = 8.dp), style = FootText) }
            }
        }
    }
}
