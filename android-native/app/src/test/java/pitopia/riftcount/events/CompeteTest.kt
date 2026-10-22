package pitopia.riftcount.events

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The iOS bracket self-check (tools/check-standings/main.swift): Swiss in section 0, the cut after it. */
class CompeteBracketTest {
    private val players = listOf("p1" to "Ann", "p2" to "Bo", "p3" to "Cy", "p4" to "Di", "p5" to "Eve", "p6" to "Fay", "p7" to "Gus", "p8" to "Hal", "p9" to "Ida", "p10" to "Jo")
    private val teams = (0 until 5).map { team("T${it + 1}", players.subList(2 * it, 2 * it + 2)) }

    private fun team(id: String, ps: List<Pair<String, String>>) = buildJsonObject {
        put("esportsTeamId", id)
        put("players", buildJsonArray { ps.forEach { (pid, name) -> add(buildJsonObject { put("id", pid); put("displayName", name) }) } })
    }

    private fun outcomes(a: JsonObject, b: JsonObject, winner: String?) = buildJsonArray {
        if (winner != null) listOf(a, b).forEach { t ->
            val id = (t["esportsTeamId"] as JsonPrimitive).content
            add(buildJsonObject { put("esportsTeamId", id); put("outcome", if (id == winner) "WIN" else "LOSS") })
        }
    }

    private fun match(id: String, a: JsonObject, b: JsonObject, winner: String?) = buildJsonObject {
        put("esportsMatchId", id)
        put("tableNumber", 1)
        put("status", "IN_PROGRESS")
        put("teams", JsonArray(listOf(a, b)))
        put("teamOutcomes", outcomes(a, b, winner))
        put("games", buildJsonArray { add(buildJsonObject { put("esportsGameId", "$id-g1"); put("number", 1); put("teamOutcomes", outcomes(a, b, winner)) }) })
    }

    private fun round(n: Int, status: String, matches: List<JsonObject>, byes: List<String> = emptyList(), standings: List<String> = emptyList()) = buildJsonObject {
        put("roundNumber", n)
        put("status", status)
        put("matches", JsonArray(matches))
        put("byeTeamIds", JsonArray(byes.map(::JsonPrimitive)))
        put("endOfRoundStandings", JsonArray(standings.mapIndexed { i, t -> buildJsonObject { put("esportsTeamId", t); put("rank", i + 1) } }))
    }

    private val swiss = listOf(
        round(1, "FINALIZED", listOf(match("m1", teams[0], teams[1], "T1"), match("m2", teams[2], teams[3], "T3")), byes = listOf("T5")),
        round(2, "FINALIZED", listOf(match("m3", teams[0], teams[2], "T1"), match("m4", teams[1], teams[4], "T2")), byes = listOf("T4"), standings = listOf("T1", "T2", "T3", "T4", "T5")),
    )

    private fun cut(final: String, from: Int) = listOf(
        round(from, "FINALIZED", listOf(match("m5", teams[0], teams[3], "T1"), match("m6", teams[1], teams[2], "T3"))),
        round(from + 1, final, listOf(match("m7", teams[0], teams[2], "T3"))),
    )

    private fun bracket(sections: List<List<JsonElement>>, structure: String = "SWISS_PLUS_SINGLE_ELIM"): Tournament {
        val json = buildJsonObject {
            put("id", "check")
            put("name", "Bracket check")
            put("config", buildJsonObject { put("structure", structure); put("roundCount", 2); put("playerFormat", "TWO_V_TWO") })
            put("stages", buildJsonArray { add(buildJsonObject { put("sections", JsonArray(sections.map { s -> buildJsonObject { put("rounds", JsonArray(s)) } })) }) })
            put("tournamentParticipants", buildJsonArray {
                players.forEachIndexed { i, (pid, name) ->
                    add(buildJsonObject {
                        put("id", "part-$pid")
                        put("esportsTeamId", "T${i / 2 + 1}")
                        put("status", if (i >= 8) "ELIMINATED" else "ACTIVE")
                        put("player", buildJsonObject { put("id", pid); put("displayName", name) })
                    })
                }
            })
        }
        return CompeteJson.decodeFromJsonElement(Tournament.serializer(), json)
    }

    @Test
    fun `cut as its own section and as continued rounds reads the same`() {
        for (t in listOf(bracket(listOf(swiss, cut("FINALIZED", 1))), bracket(listOf(swiss + cut("FINALIZED", 3))))) {
            assertEquals(4, t.rounds.map { it.id }.toSet().size)
            assertEquals(listOf("Round 1", "Round 2", "Semifinal", "Final"), t.rounds.map { t.title(it) })
            assertEquals(listOf("R1", "R2", "SF", "F"), t.rounds.map { t.shortTitle(it) })
            assertTrue(t.swissRounds.size == 2 && t.isFinished)
            assertEquals(Placement.Rank(1), t.placement("T3"))
            assertEquals(Placement.Rank(2), t.placement("T1"))
            assertEquals(Placement.Top(4), t.placement("T2"))
            assertEquals(Placement.Top(4), t.placement("T4"))
            assertEquals(Placement.Rank(5), t.placement("T5"))
            assertEquals("Eve & Fay", t.teamName("T3"))
            assertEquals(PlayerState.Eliminated, t.state("p9"))
            assertEquals(PlayerState.Active, t.state("p1"))
            val table = Standings.compute(t, 2)
            assertEquals(5, table.rows.size)
            assertEquals("top-cut wins stay out of the Swiss table", 6, table.rows.first { it.esportsTeamId == "T1" }.matchPoints)
            val final = Pairing.latest(t, "p1") ?: error("no final pairing")
            assertEquals("Final", final.roundTitle)
            assertEquals("Eve & Fay", final.opponentName)
            assertEquals("Bo", final.teammateName)
            assertEquals("part-p1", final.myParticipantId)
            assertEquals("part-p5", final.opponentParticipantId)
            assertEquals(Pairing.Result.Loss, final.result)
        }
    }

    @Test
    fun `an unpublished final is hidden and the semifinal is the latest round`() {
        val pending = bracket(listOf(swiss, cut("PENDING", 1)))
        assertEquals(3, pending.rounds.size)
        assertFalse(pending.isFinished)
        assertNull(pending.placement("T3"))
        assertEquals("Gus & Hal", Pairing.latest(pending, "p1")?.opponentName)
    }

    @Test
    fun `swiss only waits for Riot's last table before a final standing`() {
        fun lastRound(status: String) = round(2, status, listOf(match("m3", teams[0], teams[2], "T1"), match("m4", teams[1], teams[4], "T2")), byes = listOf("T4"))
        val unpublished = bracket(listOf(listOf(swiss[0], lastRound("IN_PROGRESS"))), structure = "SWISS")
        assertFalse(unpublished.isFinished)
        assertNull(unpublished.placement("T1"))
        val published = bracket(listOf(swiss), structure = "SWISS")
        assertTrue(published.isFinished)
        assertEquals(Placement.Rank(1), published.placement("T1"))
    }

    @Test
    fun `report never depends on how a published round's status reads`() {
        for (status in listOf("READY", "IN_PROGRESS", "FINALIZED", "SOMETHING_NEW")) {
            val live = bracket(listOf(listOf(swiss[0], round(2, status, listOf(match("m3", teams[0], teams[2], null), match("m4", teams[1], teams[4], null)), byes = listOf("T4")))), structure = "SWISS")
            assertEquals(status, true, Pairing.latest(live, "p1")?.isReportable)
        }
    }

    @Test
    fun `live standings count only reported matches and keep the bookkeeping`() {
        val live = bracket(listOf(listOf(swiss[0], round(2, "IN_PROGRESS", listOf(match("m3", teams[0], teams[2], "T1"), match("m4", teams[1], teams[4], null)), byes = listOf("T4")))), structure = "SWISS")
        val table = Standings.compute(live, 2)
        assertEquals(1, table.reportedMatches)
        assertEquals(2, table.totalMatches)
        assertEquals(setOf("T2", "T5"), table.pending)
        val t1 = table.rows.first { it.esportsTeamId == "T1" }
        assertEquals(1, t1.rank)
        assertEquals("2-0-0", t1.record)
        // T4: a bye in each round counts 3 points but stays out of MW%.
        val t4 = table.rows.first { it.esportsTeamId == "T4" }
        assertEquals(3, t4.matchPoints)
        assertEquals(Standings.FLOOR, t4.matchWinPercentage ?: 0.0, 1e-9)
    }
}

class DrawCalcTest {
    @Test
    fun `locked, bubble and out`() {
        // Two rivals already above me forever, a Top 2 cut: out whatever I do.
        val far = listOf(Contender(12, 0), Contender(12, 0), Contender(0, 0))
        assertEquals(List(3) { CutChance.Out }, DrawCalc.outlook(3, 1, far, cut = 2))
        // Top 2, I have 6 with one to play: only the 6-point rival can still reach 7, so a win or a draw
        // locks me in; a loss lets the 3-point rival tie at 6 too.
        val field = listOf(Contender(3, 1), Contender(6, 1), Contender(0, 1))
        assertEquals(listOf(CutChance.Locked, CutChance.Locked, CutChance.Bubble), DrawCalc.outlook(6, 1, field, cut = 2))
        assertEquals(CutChance.Bubble, DrawCalc.chance(6, 0, field, 2, 3))
    }
}

class CompeteDecodeTest {
    @Test
    fun `numbers as strings, nulls and offsets decode`() {
        val json = """{"id":"1","name":"N","startsAt":"2026-10-21T18:30:00.000+02:00","config":{"roundCount":"5","participantCapacity":null},
            "stages":[{"sections":[{"rounds":[{"roundNumber":"1","roundDuration":"50","matches":null,"endOfRoundStandings":[{"esportsTeamId":"a","matchPoints":"3","opponentMatchWinPercentage":"45.5%"}]}]}]}]}"""
        val t = CompeteJson.decodeFromString(Tournament.serializer(), json)
        assertEquals(1_792_600_200_000L, t.startsAt)
        assertEquals(5, t.config?.roundCount)
        assertNull(t.config?.participantCapacity)
        val r = t.rounds.single()
        assertEquals(1, r.number)
        assertEquals(50, r.roundDuration)
        assertTrue(r.matches.isEmpty())
        assertEquals(45.5, r.endOfRoundStandings?.single()?.opponentMatchWinPercentage ?: 0.0, 1e-9)
    }

    @Test
    fun `an unreadable node drops out of the page`() {
        val json = """{"edges":[{"node":{"tournament":{"id":"ok","name":"Fine"}}},{"node":{"tournament":42}}],"pageInfo":{"endCursor":"c","hasNextPage":true}}"""
        val c = CompeteJson.decodeFromString(Connection.serializer(), json)
        assertEquals(listOf("ok"), c.nodes(TournamentEntry.serializer()).map { it.tournament.id })
        assertEquals("c", c.nextCursor)
    }
}
