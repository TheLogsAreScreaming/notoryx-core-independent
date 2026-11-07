package com.bastionmesh.notoryx_core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app's process alive while it holds a radio connection, so the
 * Bluetooth, USB or TCP link and message alerts keep working with the app
 * in the background. Shows one quiet, ongoing notification.
 */
class KeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: lastText
        val notification = build(this, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "keep_alive"
        private const val NOTIFICATION_ID = 7001
        private const val EXTRA_TEXT = "text"

        @Volatile private var running = false
        @Volatile private var lastText = ""

        /** Starts the service, or just updates its text when it's running. */
        fun show(context: Context, text: String) {
            lastText = text
            if (running) {
                // Restarting from the background is restricted on new
                // Android; updating the notification never is.
                manager(context).notify(NOTIFICATION_ID, build(context, text))
                return
            }
            val intent = Intent(context, KeepAliveService::class.java)
                .putExtra(EXTRA_TEXT, text)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Not allowed right now (app in the background): the
                // connection still works while Android lets the app run.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, KeepAliveService::class.java))
            running = false
        }

        private fun manager(context: Context) =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        private fun build(context: Context, text: String): Notification {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager(context).createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Radio connection",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = "Shown while the app stays connected to your radio"
                        setShowBadge(false)
                    },
                )
            }
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            return builder
                .setContentTitle("NOTORYX Independent")
                .setContentText(text)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(open)
                .setOngoing(true)
                .setShowWhen(false)
                .build()
        }
    }
}
