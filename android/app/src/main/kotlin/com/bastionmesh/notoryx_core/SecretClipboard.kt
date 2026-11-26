package com.bastionmesh.notoryx_core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Copies SARNEG text and makes sure it is cleared again, even if the app is
 * frozen or killed in the meantime.
 *
 * Samsung phones freeze an app about half a minute after it leaves the
 * screen and may kill it soon after, so a timer inside the app can't be
 * trusted. The clear is scheduled with AlarmManager instead, which starts
 * [ClipboardClearReceiver] on time. As a backstop, an overdue clear also
 * runs the next time the app comes to the front.
 *
 * Only a SHA-256 of the copied text is kept, never the text itself. When the
 * clipboard can be read and holds something else, it is left alone; when it
 * can't be read (Android 10+ in the background), it is cleared anyway.
 */
object SecretClipboard {
    private const val PREFS = "notoryx_secret_clipboard"
    private const val KEY_DUE = "clear_due_ms"
    private const val KEY_HASH = "text_sha256"

    // ClipDescription.EXTRA_IS_SENSITIVE on Android 13+; older keyboards
    // read the same key by name.
    private const val IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "notoryx/clipboard").setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitive" -> {
                    val args = call.arguments
                    val text = when (args) {
                        is String -> args
                        is Map<*, *> -> args["text"] as? String
                        else -> null
                    }
                    if (text == null) {
                        result.error("args", "copySensitive needs the text", null)
                        return@setMethodCallHandler
                    }
                    val clearAfterMs =
                        ((args as? Map<*, *>)?.get("clearAfterMs") as? Number)?.toLong() ?: 0L
                    copy(app, text, clearAfterMs)
                    result.success(null)
                }
                "clear" -> {
                    clear(app)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Copies [text] marked sensitive; clears it after [clearAfterMs] if > 0. */
    fun copy(context: Context, text: String, clearAfterMs: Long) {
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(
                if (Build.VERSION.SDK_INT >= 33) ClipDescription.EXTRA_IS_SENSITIVE else IS_SENSITIVE,
                true,
            )
        }
        clipboard(context).setPrimaryClip(clip)
        if (clearAfterMs > 0) {
            val due = System.currentTimeMillis() + clearAfterMs
            prefs(context).edit()
                .putLong(KEY_DUE, due)
                .putString(KEY_HASH, sha256(text))
                .commit()
            alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, pending(context))
        } else {
            cancel(context)
        }
    }

    /** Removes the clip now and cancels any scheduled clear. */
    fun clear(context: Context) {
        removeClip(context)
        cancel(context)
    }

    /** Runs a scheduled clear: skips a clipboard that visibly holds other text. */
    fun clearScheduled(context: Context) {
        val hash = prefs(context).getString(KEY_HASH, null)
        val now = readText(context)
        if (now == null || hash == null || sha256(now) == hash) removeClip(context)
        cancel(context)
    }

    /** The backstop: runs a clear whose time has passed. */
    fun clearIfDue(context: Context) {
        val due = prefs(context).getLong(KEY_DUE, 0L)
        if (due > 0L && System.currentTimeMillis() >= due) clearScheduled(context)
    }

    private fun cancel(context: Context) {
        alarms(context).cancel(pending(context))
        prefs(context).edit().remove(KEY_DUE).remove(KEY_HASH).commit()
    }

    private fun removeClip(context: Context) {
        val cm = clipboard(context)
        if (Build.VERSION.SDK_INT >= 28) {
            cm.clearPrimaryClip()
        } else {
            cm.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    /** The clipboard text, or null when Android won't let us read it. */
    private fun readText(context: Context): String? = try {
        clipboard(context).primaryClip?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)?.text?.toString()
    } catch (e: SecurityException) {
        null
    }

    private fun sha256(text: String): String =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray())
            .joinToString("") { "%02x".format(it) }

    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ClipboardClearReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun alarms(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun clipboard(context: Context) =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
}

/** Started by AlarmManager when copied SARNEG text is due to be cleared. */
class ClipboardClearReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SecretClipboard.clearScheduled(context.applicationContext)
    }
}
