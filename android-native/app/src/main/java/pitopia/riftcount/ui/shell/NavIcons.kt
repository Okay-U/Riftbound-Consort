package pitopia.riftcount.ui.shell

import pitopia.riftcount.ui.common.lineIcon

/** Line icons of the bottom bar, traced 1:1 from the mocks (24 viewport, 2 stroke, round ends). */
object NavIcons {
    /** Upright like the board: two halves, a score in each (the mock's lay-flat one read as a football pitch). */
    val Score = lineIcon("M4 6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3zM4 12h16M12 6.5v2.5M12 15v2.5")
    val Events = lineIcon("M6 5h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3zM3 10h18M8 3v4M16 3v4")
    val Cards = lineIcon("M5 7h9a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM8 4h11a2 2 0 0 1 2 2v12")
    /** Three layers: a pile. */
    val Decks = lineIcon("M12 2.5l9 5-9 5-9-5zM3 12l9 5 9-5M3 16.5l9 5 9-5")
    /** A gear of eight teeth (the mock's rays read as a sun). */
    val Settings = lineIcon(
        "M10.19 5.24L10.42 2.53A9.6 9.6 0 0 1 13.58 2.53L13.81 5.24A7 7 0 0 1 15.5 5.94L17.57 4.18A9.6 9.6 0 0 1 19.82 6.43" +
            "L18.06 8.5A7 7 0 0 1 18.76 10.19L21.47 10.42A9.6 9.6 0 0 1 21.47 13.58L18.76 13.81A7 7 0 0 1 18.06 15.5" +
            "L19.82 17.57A9.6 9.6 0 0 1 17.57 19.82L15.5 18.06A7 7 0 0 1 13.81 18.76L13.58 21.47A9.6 9.6 0 0 1 10.42 21.47" +
            "L10.19 18.76A7 7 0 0 1 8.5 18.06L6.43 19.82A9.6 9.6 0 0 1 4.18 17.57L5.94 15.5A7 7 0 0 1 5.24 13.81" +
            "L2.53 13.58A9.6 9.6 0 0 1 2.53 10.42L5.24 10.19A7 7 0 0 1 5.94 8.5L4.18 6.43A9.6 9.6 0 0 1 6.43 4.18" +
            "L8.5 5.94A7 7 0 0 1 10.19 5.24ZM9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0z",
    )
}
