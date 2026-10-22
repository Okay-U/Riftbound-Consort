// The lenient serializers' nullable descriptors.
@file:OptIn(ExperimentalSerializationApi::class)

package pitopia.riftcount.events

import java.time.Instant
import java.time.OffsetDateTime
import kotlin.math.abs
import kotlin.math.roundToLong
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.nullable
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull

/**
 * Response types of the PlayRiftbound ("Compete") GraphQL operations, iOS `CompeteModels`. Only the
 * fields the app uses; unknown fields are ignored, numbers may come as strings, dates are ISO 8601.
 */
val CompeteJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    coerceInputValues = true
    isLenient = true
}

/** Riot has sent numbers as strings and nulls where the schema says a value (iOS `Lenient`). */
object LenientInt : KSerializer<Int?> {
    override val descriptor = PrimitiveSerialDescriptor("LenientInt", PrimitiveKind.INT).nullable
    override fun deserialize(decoder: Decoder): Int? {
        val p = (decoder as? JsonDecoder)?.decodeJsonElement() as? JsonPrimitive ?: return null
        p.longOrNull?.let { return it.toInt() }
        val v = p.doubleOrNull ?: p.content.trim().toDoubleOrNull() ?: return null
        return if (v.isFinite() && abs(v) < 1e9) v.roundToLong().toInt() else null
    }
    override fun serialize(encoder: Encoder, value: Int?) {
        if (value == null) encoder.encodeNull() else encoder.encodeInt(value)
    }
}

object LenientDouble : KSerializer<Double?> {
    override val descriptor = PrimitiveSerialDescriptor("LenientDouble", PrimitiveKind.DOUBLE).nullable
    override fun deserialize(decoder: Decoder): Double? {
        val p = (decoder as? JsonDecoder)?.decodeJsonElement() as? JsonPrimitive ?: return null
        return p.doubleOrNull ?: p.content.replace("%", "").trim().toDoubleOrNull()
    }
    override fun serialize(encoder: Encoder, value: Double?) {
        if (value == null) encoder.encodeNull() else encoder.encodeDouble(value)
    }
}

/** ISO 8601 with or without fractional seconds and offset, as epoch milliseconds. */
object IsoTime : KSerializer<Long?> {
    override val descriptor = PrimitiveSerialDescriptor("IsoTime", PrimitiveKind.STRING).nullable
    override fun deserialize(decoder: Decoder): Long? {
        val p = (decoder as? JsonDecoder)?.decodeJsonElement() as? JsonPrimitive ?: return null
        return parse(p.content)
    }
    override fun serialize(encoder: Encoder, value: Long?) {
        if (value == null) encoder.encodeNull() else encoder.encodeString(Instant.ofEpochMilli(value).toString())
    }

    fun parse(raw: String): Long? = runCatching { OffsetDateTime.parse(raw).toInstant().toEpochMilli() }.getOrNull()
        ?: runCatching { Instant.parse(raw).toEpochMilli() }.getOrNull()
}

@Serializable
data class GraphQLError(val message: String = "", val extensions: Extensions? = null) {
    @Serializable
    data class Extensions(val code: String? = null)
}

/** `{data, errors}`; `data` stays a tree so each operation decodes its own shape. */
@Serializable
data class GraphQLEnvelope(val data: JsonElement? = null, val errors: List<GraphQLError>? = null)

/** A Relay connection; a node that cannot be read drops out instead of failing the page. */
@Serializable
data class Connection(val edges: List<Edge> = emptyList(), val pageInfo: PageInfo? = null) {
    @Serializable
    data class Edge(val cursor: String? = null, val node: JsonElement? = null)

    @Serializable
    data class PageInfo(val endCursor: String? = null, val hasNextPage: Boolean = false)

    fun <T> nodes(serializer: KSerializer<T>): List<T> =
        edges.mapNotNull { e -> e.node?.let { runCatching { CompeteJson.decodeFromJsonElement(serializer, it) }.getOrNull() } }

    val nextCursor: String? get() = pageInfo?.takeIf { it.hasNextPage }?.endCursor
}

@Serializable
data class Organizer(
    val id: String,
    val name: String = "Store",
    val isFavorited: Boolean? = null,
    val physicalAddress: Address? = null,
) {
    @Serializable
    data class Address(
        val city: String? = null,
        val adminArea1: String? = null,
        val formattedAddress: String? = null,
        @Serializable(with = LenientDouble::class) val latitude: Double? = null,
        @Serializable(with = LenientDouble::class) val longitude: Double? = null,
    )
}

@Serializable
data class EntryFee(val currency: String = "EUR", @Serializable(with = LenientInt::class) val minorUnits: Int? = 0)

@Serializable
data class RegistrantCount(val status: String = "", @Serializable(with = LenientInt::class) val count: Int? = 0)

@Serializable
data class SummaryConfig(
    val tournamentType: String? = null,
    val format: String? = null,
    val playerFormat: String? = null,
    @Serializable(with = LenientInt::class) val participantCapacity: Int? = null,
)

/** A tournament as the lists show it (my events, search). */
@Serializable
data class TournamentSummary(
    val id: String,
    val name: String = "Event",
    @Serializable(with = IsoTime::class) val startsAt: Long? = null,
    val pricing: String? = null,
    val entryFee: EntryFee? = null,
    val registrantCounts: List<RegistrantCount>? = null,
    val config: SummaryConfig? = null,
) {
    val registeredCount: Int get() = registrantCounts?.firstOrNull { it.status == "REGISTERED" }?.count ?: 0
    val webUrl: String get() = "https://playriftbound.com/en-US/events/$id"
}

/** One `RbPlayerTournamentResult` / `RbTournamentSearchResult`: the tournament and its store. */
@Serializable
data class TournamentEntry(
    val organizer: Organizer? = null,
    val tournament: TournamentSummary,
    @Serializable(with = LenientDouble::class) val distanceMeters: Double? = null,
)

@Serializable
data class PlayerTournamentsData(val playerTournaments: Lists) {
    @Serializable
    data class Lists(val upcoming: Connection = Connection(), val past: Connection = Connection())
}

@Serializable
data class SearchData(val competeTournamentSearch: Connection = Connection())

@Serializable
data class TournamentsData(val competeTournaments: List<Tournament> = emptyList())

@Serializable
data class FavoritesData(val favoritedOrganizers: List<Organizer> = emptyList())

@Serializable
data class OrganizerSummaryData(val organizerSummary: OrganizerSummary? = null)

@Serializable
data class OrganizerSummary(
    val id: String,
    val name: String = "Store",
    val email: String? = null,
    val website: String? = null,
    val phone: Phone? = null,
    val physicalAddress: Organizer.Address? = null,
) {
    @Serializable
    data class Phone(val countryDialingCode: String? = null, val number: String? = null) {
        val display: String?
            get() = number?.takeIf { it.isNotBlank() }?.let { n ->
                listOfNotNull(countryDialingCode?.let { if (it.startsWith("+")) it else "+$it" }, n).joinToString(" ")
            }
    }
}

/** One tournament with its bracket: stages → sections → rounds → matches (the `CompeteRb*` fragments). */
@Serializable
data class Tournament(
    val id: String,
    val name: String = "Event",
    val description: String? = null,
    val tournamentProgram: Program? = null,
    @Serializable(with = IsoTime::class) val startsAt: Long? = null,
    @Serializable(with = IsoTime::class) val endsAt: Long? = null,
    @Serializable(with = IsoTime::class) val registrationEndAt: Long? = null,
    val pricing: String? = null,
    val entryFee: EntryFee? = null,
    val registrantCounts: List<RegistrantCount>? = null,
    val config: Config? = null,
    val stages: List<Stage> = emptyList(),
    val tournamentRegistrants: List<Registrant>? = null,
    val tournamentParticipants: List<Participant>? = null,
) {
    @Serializable
    data class Program(val id: String? = null, val programName: String? = null)

    @Serializable
    data class Config(
        val tournamentType: String? = null,
        val format: String? = null,
        val playerFormat: String? = null,
        val structure: String? = null,
        val matchFormat: String? = null,
        @Serializable(with = LenientInt::class) val participantCapacity: Int? = null,
        @Serializable(with = LenientInt::class) val roundCount: Int? = null,
    )

    @Serializable
    data class Stage(val esportsStageId: String? = null, val name: String? = null, val sections: List<Section> = emptyList())

    @Serializable
    data class Section(val esportsSectionId: String? = null, val rounds: List<Round> = emptyList())

    @Serializable
    data class Round(
        @Serializable(with = LenientInt::class) val roundNumber: Int? = 0,
        val status: String? = null,
        @Serializable(with = IsoTime::class) val startedAt: Long? = null,
        /** Minutes. */
        @Serializable(with = LenientInt::class) val roundDuration: Int? = null,
        val byeTeamIds: List<String>? = null,
        val droppedTeamIds: List<String>? = null,
        val matches: List<Match> = emptyList(),
        val endOfRoundStandings: List<Standing>? = null,
        /** Position of the round's section across all stages: 0 for Swiss, 1+ for a later section (top cut). */
        val sectionIndex: Int = 0,
    ) {
        val number: Int get() = roundNumber ?: 0
        val id: String get() = "$sectionIndex-$number"
        /** The round clock's end: start plus its minutes (60 when the event sets none). */
        val endsAt: Long? get() = startedAt?.let { it + (roundDuration ?: 60) * 60_000L }
    }

    @Serializable
    data class Match(
        val esportsMatchId: String,
        @Serializable(with = LenientInt::class) val tableNumber: Int? = null,
        val status: String? = null,
        val config: MatchConfig? = null,
        val teams: List<Team> = emptyList(),
        val games: List<Game>? = null,
        val teamOutcomes: List<Outcome>? = null,
    ) {
        val isComplete: Boolean get() = status == "COMPLETED" || !teamOutcomes.isNullOrEmpty()
    }

    @Serializable
    data class MatchConfig(@Serializable(with = LenientInt::class) val count: Int? = null)

    @Serializable
    data class Team(val esportsTeamId: String, val players: List<Player> = emptyList())

    @Serializable
    data class Player(val id: String, val displayName: String? = null)

    @Serializable
    data class Game(
        val esportsGameId: String,
        @Serializable(with = LenientInt::class) val number: Int? = null,
        val teamOutcomes: List<Outcome>? = null,
    )

    @Serializable
    data class Outcome(val esportsTeamId: String? = null, val outcome: String? = null) {
        val isWin: Boolean get() = outcome?.uppercase()?.contains("WIN") == true
    }

    @Serializable
    data class Standing(
        val esportsTeamId: String = "",
        @Serializable(with = LenientInt::class) val rank: Int? = null,
        @Serializable(with = LenientInt::class) val matchPoints: Int? = null,
        @Serializable(with = LenientInt::class) val matchWins: Int? = null,
        @Serializable(with = LenientInt::class) val matchLosses: Int? = null,
        @Serializable(with = LenientInt::class) val matchDraws: Int? = null,
        @Serializable(with = LenientDouble::class) val matchWinPercentage: Double? = null,
        @Serializable(with = LenientDouble::class) val opponentMatchWinPercentage: Double? = null,
        @Serializable(with = LenientDouble::class) val gameWinPercentage: Double? = null,
        @Serializable(with = LenientDouble::class) val opponentGameWinPercentage: Double? = null,
    ) {
        val record: String get() = "${matchWins ?: 0}-${matchLosses ?: 0}-${matchDraws ?: 0}"
    }

    @Serializable
    data class Registrant(val id: String, val status: String? = null, val checkedIn: Boolean? = null, val player: RegistrantPlayer? = null)

    @Serializable
    data class RegistrantPlayer(val id: String, val displayName: String? = null, val tagLine: String? = null)

    @Serializable
    data class Participant(
        /** What `SubmitGameResults` wants as `winnerParticipantId`. */
        val id: String,
        val esportsTeamId: String? = null,
        val status: String? = null,
        /** Seed, as the site shows it (#n). */
        @Serializable(with = LenientInt::class) val position: Int? = null,
        val player: RegistrantPlayer? = null,
    )
}
