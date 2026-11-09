package com.bastionmesh.notoryx_core

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Home-screen widget: connection status, and shortcuts into Safety. */
class StatusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        const val ACTION_OPEN_SAFETY = "com.bastionmesh.notoryx_core.OPEN_SAFETY"
        private const val PREFS = "notoryx_status_widget"

        fun update(context: Context, status: String, detail: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("status", status)
                .putString("detail", detail)
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, StatusWidget::class.java))
            render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.status_widget)
            views.setTextViewText(R.id.widget_status, prefs.getString("status", "Open the app"))
            views.setTextViewText(R.id.widget_detail, prefs.getString("detail", ""))
            views.setOnClickPendingIntent(R.id.widget_root, launch(context, null, 0))
            // Both only open the Safety screen. Sending an SOS always takes
            // the deliberate hold there, so a pocket can't send one.
            val safety = launch(context, ACTION_OPEN_SAFETY, 1)
            views.setOnClickPendingIntent(R.id.widget_sos, safety)
            views.setOnClickPendingIntent(R.id.widget_check_in, safety)
            manager.updateAppWidget(ids, views)
        }

        private fun launch(context: Context, action: String?, code: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(action ?: Intent.ACTION_MAIN)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
