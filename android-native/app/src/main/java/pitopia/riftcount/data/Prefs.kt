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

    fun put(key: String, value: String) = sp.edit().putString(key, value).apply()
    fun put(key: String, value: Boolean) = sp.edit().putBoolean(key, value).apply()
    fun put(key: String, value: Int) = sp.edit().putInt(key, value).apply()
}
