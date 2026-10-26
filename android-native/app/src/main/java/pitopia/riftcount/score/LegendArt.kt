package pitopia.riftcount.score

/**
 * Legend art (iOS `LegendArt`, docs/IOS_REDESIGN.md "Score tile look"): a half shows its legend's champion as Data
 * Dragon's base splash, loaded when needed, so the app carries no pictures and a new legend works by itself.
 */
object LegendArt {
    /** Data Dragon ids that are not the champion's letters: every one of the 173 champions on 16.13. */
    private val ids = mapOf(
        "Bel'Veth" to "Belveth", "Cho'Gath" to "Chogath", "Kai'Sa" to "Kaisa", "Kha'Zix" to "Khazix", "LeBlanc" to "Leblanc",
        "Wukong" to "MonkeyKing", "Nunu & Willump" to "Nunu", "Renata Glasc" to "Renata", "Vel'Koz" to "Velkoz",
    )
    private val Printing = Regex("""\s*\(.*?\)\s*$""")

    /** The champion a legend is: "Kai'Sa - Daughter of the Void (Signature)" or "Kai'Sa, …" is "Kai'Sa". */
    fun champion(legend: String): String =
        legend.replace(Printing, "").substringBefore(" - ").substringBefore(", ").trim()

    /** The champion's base splash; null without a name. */
    fun url(legend: String): String? {
        val champion = champion(legend)
        val id = ids[champion] ?: champion.filter { it in 'A'..'Z' || it in 'a'..'z' }
        return if (id.isEmpty()) null else "https://ddragon.leagueoflegends.com/cdn/img/champion/centered/${id}_0.jpg"
    }
}
