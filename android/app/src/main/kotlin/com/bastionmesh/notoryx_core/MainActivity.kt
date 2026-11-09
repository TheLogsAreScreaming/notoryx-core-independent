package com.bastionmesh.notoryx_core

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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
    }

    private fun batteryUnrestricted(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    // Sideloaded app: asking directly is allowed and is one tap for the person.
    @SuppressLint("BatteryLife")
    private fun requestBatteryUnrestricted() {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        try {
            startActivity(direct)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }
}
