package com.abhiflex.finnai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Turns a [FinnHomeWidgetSpec] into the `RemoteViews` a launcher draws.
 *
 * Everything a widget shows is text, so the accent colour is applied to a bar
 * and to the title rather than to the background: `RemoteViews` can only set a
 * flat colour on a view, which would discard the rounded surface.
 */
object FinnHomeWidgetRenderer {
    /** Rows the layout declares; must match `finn_home_widget.xml`. */
    private const val MAX_ROWS = 4

    private val rowIds = intArrayOf(
        R.id.finn_widget_row_1,
        R.id.finn_widget_row_2,
        R.id.finn_widget_row_3,
        R.id.finn_widget_row_4,
    )

    private val labelIds = intArrayOf(
        R.id.finn_widget_label_1,
        R.id.finn_widget_label_2,
        R.id.finn_widget_label_3,
        R.id.finn_widget_label_4,
    )

    private val valueIds = intArrayOf(
        R.id.finn_widget_value_1,
        R.id.finn_widget_value_2,
        R.id.finn_widget_value_3,
        R.id.finn_widget_value_4,
    )

    fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        manager.updateAppWidget(appWidgetId, build(context, appWidgetId))
    }

    fun build(context: Context, appWidgetId: Int): RemoteViews {
        val spec = FinnHomeWidgetStore.specFor(context, appWidgetId)
        return if (spec == null) emptyViews(context) else specViews(context, spec)
    }

    /** Shown before a creation is chosen, or after app data was cleared. */
    private fun emptyViews(context: Context): RemoteViews =
        RemoteViews(context.packageName, R.layout.finn_home_widget).apply {
            setTextViewText(R.id.finn_widget_title, context.getString(R.string.finn_widget_label))
            setTextViewText(
                R.id.finn_widget_footer,
                context.getString(R.string.finn_widget_description),
            )
            setViewVisibility(R.id.finn_widget_accent, View.GONE)
            for (index in 0 until MAX_ROWS) {
                setViewVisibility(rowIds[index], View.GONE)
            }
            setOnClickPendingIntent(R.id.finn_widget_root, openApp(context, 0))
        }

    private fun specViews(context: Context, spec: FinnHomeWidgetSpec): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.finn_home_widget)
        views.setTextViewText(R.id.finn_widget_title, spec.title)
        views.setTextColor(R.id.finn_widget_title, spec.accent)
        views.setInt(R.id.finn_widget_accent, "setBackgroundColor", spec.accent)
        views.setViewVisibility(R.id.finn_widget_accent, View.VISIBLE)

        for (index in 0 until MAX_ROWS) {
            val row = spec.rows.getOrNull(index)
            if (row == null) {
                views.setViewVisibility(rowIds[index], View.GONE)
                continue
            }
            views.setViewVisibility(rowIds[index], View.VISIBLE)
            views.setTextViewText(labelIds[index], row.first)
            views.setTextViewText(valueIds[index], row.second)
        }

        if (spec.footer.isEmpty()) {
            views.setViewVisibility(R.id.finn_widget_footer, View.GONE)
        } else {
            views.setViewVisibility(R.id.finn_widget_footer, View.VISIBLE)
            views.setTextViewText(R.id.finn_widget_footer, spec.footer)
        }

        views.setOnClickPendingIntent(R.id.finn_widget_root, openApp(context, spec.title.hashCode()))
        return views
    }

    private fun openApp(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        // targetSdk 31+ rejects mutable PendingIntents for this use.
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
