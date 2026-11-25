package com.bastionmesh.notoryx_core

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * "notoryx/clipboard" for SARNEG text.
 *
 * copySensitive(text): copies with the "sensitive" flag, so Android and
 * keyboards don't show it in previews or keep it in clipboard history.
 * clear(): removes the clip, so nothing is left to paste.
 */
object SecretClipboardChannel {
    // ClipDescription.EXTRA_IS_SENSITIVE on Android 13+; older keyboards
    // read the same key by name.
    private const val IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"

    fun register(context: Context, messenger: BinaryMessenger) {
        val clipboard =
            context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        MethodChannel(messenger, "notoryx/clipboard").setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitive" -> {
                    val text = call.arguments as? String
                    if (text == null) {
                        result.error("args", "copySensitive needs the text", null)
                        return@setMethodCallHandler
                    }
                    val clip = ClipData.newPlainText("", text)
                    clip.description.extras = PersistableBundle().apply {
                        putBoolean(
                            if (Build.VERSION.SDK_INT >= 33) {
                                ClipDescription.EXTRA_IS_SENSITIVE
                            } else {
                                IS_SENSITIVE
                            },
                            true,
                        )
                    }
                    clipboard.setPrimaryClip(clip)
                    result.success(null)
                }
                "clear" -> {
                    if (Build.VERSION.SDK_INT >= 28) {
                        clipboard.clearPrimaryClip()
                    } else {
                        clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
