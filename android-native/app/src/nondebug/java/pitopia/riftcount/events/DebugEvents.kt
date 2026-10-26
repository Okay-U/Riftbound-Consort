package pitopia.riftcount.events

import android.content.Context

/** Release and staging builds: no debug tools (the fake live event is in src/debug), always the network. */
object DebugEvents {
    const val TOOLS = false

    fun isOn(context: Context) = false

    fun switch(context: Context, on: Boolean) = Unit

    fun transport(context: Context): Transport = HttpTransport
}
