package pitopia.riftcount.score

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** A legend's name to Data Dragon's splash (iOS tools/check-scoreboard, the same cases). */
class LegendArtTest {
    private fun id(legend: String) = LegendArt.url(legend)?.substringAfterLast('/')

    @Test
    fun `names become Data Dragon ids`() {
        assertEquals("Jinx_0.jpg", id("Jinx - Loose Cannon"))
        assertEquals("Kaisa_0.jpg", id("Kai'Sa - Daughter of the Void"))
        assertEquals("Leblanc_0.jpg", id("LeBlanc - Deceiver"))
        assertEquals("Renata_0.jpg", id("Renata Glasc - Chem-Baroness"))
        assertEquals("Khazix_0.jpg", id("Kha'Zix - Voidreaver"))
        assertEquals("JarvanIV_0.jpg", id("Jarvan IV - Exemplar of Demacia"))
        assertEquals("KSante_0.jpg", id("K'Sante - Pride of Nazumah"))
        assertEquals("MasterYi_0.jpg", id("Master Yi - Wuju Master"))
        assertEquals("LeeSin_0.jpg", id("Lee Sin, Blind Monk"))
        assertEquals("Darius_0.jpg", id("Darius - Hand of Noxus (Signature)"))
    }

    @Test
    fun `no name has no picture`() {
        assertNull(LegendArt.url(""))
        assertNull(LegendArt.url("  "))
    }
}
