package pitopia.riftcount.ui.shell

import pitopia.riftcount.ui.common.lineIcon

/** Line icons of the bottom bar, traced 1:1 from the mocks (24 viewport, 2 stroke, round ends). */
object NavIcons {
    val Score = lineIcon("M6 4h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zM12 4v16M7 10v4M17 10v4")
    val Events = lineIcon("M6 5h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3zM3 10h18M8 3v4M16 3v4")
    val Cards = lineIcon("M5 7h9a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM8 4h11a2 2 0 0 1 2 2v12")
    val Decks = lineIcon("M12 3l9 5-9 5-9-5zM3 13l9 5 9-5")
    val Settings = lineIcon(
        "M8.5 12a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0zM12 2v3M12 19v3M2 12h3M19 12h3" +
            "M4.9 4.9L7 7M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1",
    )
}
