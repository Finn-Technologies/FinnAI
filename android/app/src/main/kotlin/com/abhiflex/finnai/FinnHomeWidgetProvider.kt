package com.abhiflex.finnai

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

/**
 * Launcher entry point for FinnAI widgets.
 *
 * The provider is created by the framework, so it must render without the
 * Flutter engine running: it reads the current spec from disk and rebuilds its
 * `RemoteViews` on every update.
 */
class FinnHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            FinnHomeWidgetRenderer.update(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?,
    ) {
        // Resizing can reveal or hide rows, so re-render at the new size.
        FinnHomeWidgetRenderer.update(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        FinnHomeWidgetStore.forget(context, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        if (id != -1) {
            FinnHomeWidgetRenderer.update(
                context,
                AppWidgetManager.getInstance(context),
                id,
            )
        }
    }

    companion object {
        /** Re-renders every placed widget; used after a spec changes. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for (id in FinnHomeWidgetStore.placedWidgetIds(context)) {
                FinnHomeWidgetRenderer.update(context, manager, id)
            }
        }
    }
}
