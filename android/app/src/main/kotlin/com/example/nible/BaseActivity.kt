package com.example.nible

import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

open class BaseActivity : FlutterFragmentActivity() {
    override fun attachBaseContext(newBase: Context) {
        val config = Configuration(newBase.resources.configuration)
        config.fontScale = 1.0f // Ignore user font scaling
        val context = newBase.createConfigurationContext(config)
        super.attachBaseContext(context)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val metrics = resources.displayMetrics
        val density = metrics.widthPixels / 360f // fixed width scaling
        metrics.density = density
        metrics.scaledDensity = density
        metrics.densityDpi = (160 * density).toInt()
    }
}
