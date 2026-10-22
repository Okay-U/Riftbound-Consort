package pitopia.riftcount.data

import android.content.Context
import android.content.SharedPreferences

/**
 * App settings in the Skip app's own file (`shared_prefs/defaults.xml`) under the same keys, so the
 * Play update finds every setting the old app wrote. Missing key = the iOS default.
 */
object Prefs {
    private lateinit var sp: SharedPreferences

    fun init(context: Context) {
        sp = context.getSharedPreferences("defaults", Context.MODE_PRIVATE)
    }

    fun string(key: String, default: String): String = sp.getString(key, default) ?: default
    fun bool(key: String, default: Boolean): Boolean = sp.getBoolean(key, default)
    fun int(key: String, default: Int): Int = sp.getInt(key, default)

    /** Skip's encoding of a Swift Double: the IEEE bits as a long, flagged `__unrepresentable__:<key>`. */
    fun double(key: String, default: Double): Double =
        if (sp.getInt("__unrepresentable__:$key", 0) == 1) Double.fromBits(sp.getLong(key, default.toRawBits())) else default

    fun put(key: String, value: Double) =
        sp.edit().putLong(key, value.toRawBits()).putInt("__unrepresentable__:$key", 1).apply()

    fun put(key: String, value: String) = sp.edit().putString(key, value).apply()
    fun put(key: String, value: Boolean) = sp.edit().putBoolean(key, value).apply()
    fun put(key: String, value: Int) = sp.edit().putInt(key, value).apply()
}
