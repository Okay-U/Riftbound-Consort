package pitopia.riftcount.score

import kotlin.math.pow
import kotlin.math.roundToLong
import kotlin.random.Random

enum class DieType(val sides: Int, val label: String) { D20(20, "D20"), D6(6, "D6") }

data class Die(val value: Int? = null, val rolling: Boolean = false, val rolls: Int = 0)

/** Who goes first: every player rolls, the single highest roll wins, ties roll again. */
data class DuelState(
    val type: DieType = DieType.D20,
    val dice: List<Die>,
    val winner: Int = -1,
    val tie: Boolean = false,
    val choice: Choice? = null,
) {
    enum class Choice { First, Second }

    val busy get() = dice.any { it.rolling }
    val decided get() = winner >= 0 || tie
    val canRollAll get() = !busy && !decided && dice.any { it.value == null }

    fun canRoll(slot: Int) = !decided && !dice[slot].rolling && dice[slot].value == null

    fun rolling(slot: Int) = copy(dice = dice.mapIndexed { i, d -> if (i == slot) d.copy(rolling = true) else d })

    /** One face of the tumble, or the final value when [done]. */
    fun shown(slot: Int, value: Int, done: Boolean) =
        copy(dice = dice.mapIndexed { i, d -> if (i == slot) d.copy(value = value, rolling = !done, rolls = d.rolls + 1) else d }).settled()

    private fun settled(): DuelState {
        if (dice.any { it.rolling || it.value == null }) return this
        val top = dice.maxOf { it.value ?: 0 }
        val leaders = dice.indices.filter { dice[it].value == top }
        return if (leaders.size == 1) copy(winner = leaders.single()) else copy(tie = true)
    }

    fun rerolled() = DuelState(type = type, dice = dice.map { Die() })

    /** 2 players: the winner chooses; with 4 the winner simply starts. */
    fun starter(): Int = when {
        winner < 0 -> -1
        dice.size == 2 && choice == Choice.Second -> 1 - winner
        else -> winner
    }

    companion object {
        fun start(players: Int, type: DieType = DieType.D20) = DuelState(type = type, dice = List(players) { Die() })

        /** Waits between tumbling faces: quick at first, slowing down (38 ms × 1.27ⁿ, 11 faces). */
        val tumbleWaits: List<Long> = (0 until 11).map { (38 * 1.27.pow(it)).roundToLong() }

        fun face(sides: Int, notThis: Int?, random: Random): Int {
            val v = 1 + random.nextInt(sides)
            return if (v == notThis) v % sides + 1 else v
        }
    }
}
