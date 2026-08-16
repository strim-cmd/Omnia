package com.omnia.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.omnia.app.navigation.OmniaNavHost
import com.omnia.designsystem.theme.OmniaTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container = (application as OmniaApplication).container
        enableEdgeToEdge()

        setContent {
            val themeMode by container.themeController.themeMode.collectAsStateWithLifecycle()
            OmniaTheme(themeMode = themeMode) {
                OmniaNavHost(container = container)
            }
        }
    }
}
