package com.paceora.paceora

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Ana ekran widget'ı: seri ve günün kelimesi. Veriyi uygulama yazar
 * (lib/app/home_widget_sync.dart); widget yalnızca gösterir. Dokununca
 * uygulama açılır.
 */
class PaceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pace_widget).apply {
                val streak = widgetData.getInt("streak", 0)
                setTextViewText(
                    R.id.widget_streak,
                    if (streak > 0) "🔥 $streak gün" else "🔥 Seri başlat",
                )
                setTextViewText(
                    R.id.widget_status,
                    if (widgetData.getBoolean("done_today", false)) "Bugün tamam ✓"
                    else "Bugünkü ders seni bekliyor",
                )
                setTextViewText(R.id.widget_word, widgetData.getString("word", "look forward to"))
                setTextViewText(
                    R.id.widget_meaning,
                    widgetData.getString("meaning", "dört gözle beklemek"),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
