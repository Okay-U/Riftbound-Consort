package pitopia.riftcount

import android.graphics.Color
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import pitopia.riftcount.cards.CardImages
import pitopia.riftcount.data.Prefs
import pitopia.riftcount.ui.shell.AppShell

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        Prefs.init(applicationContext)
        CardImages.init(applicationContext)
        setContent { AppShell() }
    }

    override fun onResume() {
        super.onResume()
        // iOS keeps the screen awake while the app is open; the setting can turn it off.
        if (Prefs.bool("keepScreenOn", true)) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
