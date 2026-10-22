package pitopia.riftcount.cards

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** One printing from `cards.json` (riftcodex schema, built daily from Riot's gallery), as iOS reads it. */
@Serializable
data class Card(
    val id: String,
    val name: String,
    @SerialName("riftbound_id") val riftboundId: String? = null,
    /** Printed collector code, "OGN-253/298". */
    @SerialName("public_code") val publicCode: String? = null,
    @SerialName("collector_number") val collectorNumber: Int? = null,
    val attributes: Attributes? = null,
    val classification: Classification? = null,
    val text: Text? = null,
    val set: CardSet? = null,
    val media: Media? = null,
    val tags: List<String>? = null,
    val orientation: String? = null,
    val metadata: Metadata? = null,
    /** Previewed by Riot but not legal yet; the policy asks for a visible label. */
    val unreleased: Boolean? = null,
) {
    @Serializable
    data class Attributes(val energy: Int? = null, val might: Int? = null, val power: Int? = null)

    @Serializable
    data class Classification(val type: String? = null, val supertype: String? = null, val rarity: String? = null, val domain: List<String>? = null)

    @Serializable
    data class Text(val rich: String? = null, val plain: String? = null, val flavour: String? = null)

    @Serializable
    data class CardSet(@SerialName("set_id") val setId: String? = null, val label: String? = null)

    @Serializable
    data class Media(
        @SerialName("image_url") val imageUrl: String? = null,
        val artist: String? = null,
        @SerialName("accessibility_text") val accessibilityText: String? = null,
    )

    @Serializable
    data class Metadata(
        @SerialName("clean_name") val cleanName: String? = null,
        @SerialName("updated_on") val updatedOn: String? = null,
        @SerialName("alternate_art") val alternateArt: Boolean? = null,
        val overnumbered: Boolean? = null,
        val signature: Boolean? = null,
    )

    val type: String get() = classification?.type.orEmpty()
    val supertype: String get() = classification?.supertype.orEmpty()
    val rarity: String get() = classification?.rarity.orEmpty()
    val domains: List<String> get() = classification?.domain.orEmpty()
    val isLegend get() = type.equals("legend", true)
    val isRareLegend get() = isLegend && rarity.equals("rare", true)
    /** Champion units; the "(Starter)" legends carry the champion supertype too. */
    val isChampion get() = supertype.equals("champion", true) && !isLegend
    val isBattlefield get() = type.equals("battlefield", true)
    val isRune get() = type.equals("rune", true)
    val isToken get() = supertype.equals("token", true)
    val isSignature get() = metadata?.signature == true
    val isPreview get() = unreleased == true

    /** The plain rules text without bracket codes, for one-line summaries ("[Reaction][>] Kill" → "Reaction → Kill"). */
    val summary: String?
        get() = text?.plain?.replace("[>]", " →")?.replace(Regex("\\[([^\\]]+)]"), "$1")?.replace(Regex("\\s+"), " ")?.trim()?.ifEmpty { null }

    /** The printing in the name's brackets: "Overnumbered", "Alternate Art", "Signature". */
    val printing: String? get() = Regex("\\(([^)]*)\\)\\s*$").find(name)?.groupValues?.get(1)

    /** "Darius - Hand of Noxus" → "Darius", the legend part before the comma or dash. */
    val title: String get() = name.substringBefore(" - ").substringBefore(",").trim()

    /** "Hand of Noxus"; "Eager Admirer" for "Allay, Eager Admirer"; no printing suffix. */
    val subtitle: String? get() {
        val rest = if (" - " in name) name.substringAfter(" - ") else name.substringAfter(", ", "")
        return rest.substringBefore(" (").trim().ifEmpty { null }
    }
}

/** The feed's envelope (the snapshot on disk is the bare item array). */
@Serializable
data class CardPage(val total: Int = 0, val page: Int = 0, val size: Int = 0, val items: List<Card>)
