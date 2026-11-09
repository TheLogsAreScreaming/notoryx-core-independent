package com.bastionmesh.notoryx_core

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notoryx/keep_alive")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        KeepAliveService.show(this, call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "stop" -> {
                        KeepAliveService.stop(this)
                        result.success(null)
                    }
                    "batteryUnrestricted" -> result.success(batteryUnrestricted())
                    "requestBatteryUnrestricted" -> {
                        requestBatteryUnrestricted()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notoryx/widget")
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    StatusWidget.update(
                        this,
                        call.argument<String>("status") ?: "",
                        call.argument<String>("detail") ?: "",
                    )
                    result.success(null)
                }
                "takeLaunch" -> {
                    val opened = intent?.action == StatusWidget.ACTION_OPEN_SAFETY
                    if (opened) intent.action = Intent.ACTION_MAIN
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == StatusWidget.ACTION_OPEN_SAFETY) {
            widgetChannel?.invokeMethod("openSafety", null)
        }
    }

    private fun batteryUnrestricted(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    // Opens the system list; Google Play restricts asking for the exemption directly.
    private fun requestBatteryUnrestricted() {
        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }
}
