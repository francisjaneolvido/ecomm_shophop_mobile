package com.example.shophop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shophop/device_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "appInfo") {
                    try {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        result.success(mapOf("version" to info.versionName, "build_number" to info.versionCode.toString()))
                    } catch (error: Exception) {
                        result.error("unavailable", "Cannot read app information", null)
                    }
                } else if (call.method != "notifications") {
                    result.notImplemented()
                } else {
                    try {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("unavailable", "Cannot open notification settings", null)
                    }
                }
            }
    }
}
