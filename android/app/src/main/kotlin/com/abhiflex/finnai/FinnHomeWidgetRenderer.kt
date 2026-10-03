package com.abhiflex.finnai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Turns a [FinnHomeWidgetSpec] and its [FinnWidgetState] into the `RemoteViews`
 * a launcher draws.
 *
 * Everything a widget shows is text, so the accent colour is applied to a bar,
 * the title and the buttons rather than to the background: `RemoteViews` can
 * only set a flat colour on a view, which would discard the rounded surface.
 *
 * Every control is a PendingIntent broadcast back to [FinnHomeWidgetProvider],
 * which applies the tap to the stored state and redraws. Nothing here needs
 * the Flutter engine.
 */
object FinnHomeWidgetRenderer {
    /** Rows the layout declares; must match `finn_home_widget.xml`. */
    private const val MAX_ROWS = 4

    /** Segments in a counter's goal bar; must match `finn_home_widget_counter.xml`. */
    private const val GOAL_SEGMENTS = 10

    private const val SEGMENT_EMPTY = 0xFFE6E6E2.toInt()

    private val rowIds = intArrayOf(
        R.id.finn_widget_row_1,
        R.id.finn_widget_row_2,
        R.id.finn_widget_row_3,
        R.id.finn_widget_row_4,
    )

    private val markIds = intArrayOf(
        R.id.finn_widget_mark_1,
        R.id.finn_widget_mark_2,
        R.id.finn_widget_mark_3,
        R.id.finn_widget_mark_4,
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

    private val plusIds = intArrayOf(
        R.id.finn_widget_plus_1,
        R.id.finn_widget_plus_2,
        R.id.finn_widget_plus_3,
        R.id.finn_widget_plus_4,
    )

    private val plusBackgroundIds = intArrayOf(
        R.id.finn_widget_plusbg_1,
        R.id.finn_widget_plusbg_2,
        R.id.finn_widget_plusbg_3,
        R.id.finn_widget_plusbg_4,
    )

    private val segmentIds = intArrayOf(
        R.id.finn_widget_seg_1,
        R.id.finn_widget_seg_2,
        R.id.finn_widget_seg_3,
        R.id.finn_widget_seg_4,
        R.id.finn_widget_seg_5,
        R.id.finn_widget_seg_6,
        R.id.finn_widget_seg_7,
        R.id.finn_widget_seg_8,
        R.id.finn_widget_seg_9,
        R.id.finn_widget_seg_10,
    )

    fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        manager.updateAppWidget(appWidgetId, build(context, appWidgetId))
    }

    fun build(context: Context, appWidgetId: Int): RemoteViews {
        val spec = FinnHomeWidgetStore.specFor(context, appWidgetId)
            ?: return emptyViews(context)
        val state = FinnHomeWidgetStore.stateFor(context, spec)
        return when (spec.kind) {
            FinnWidgetKind.COUNTER -> counterViews(context, appWidgetId, spec, state)
            else -> listViews(context, appWidgetId, spec, state)
        }
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

    private fun counterViews(
        context: Context,
        appWidgetId: Int,
        spec: FinnHomeWidgetSpec,
        state: FinnWidgetState,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.finn_home_widget_counter)
        header(views, spec)
        views.setTextViewText(R.id.finn_widget_label_1, spec.rows.firstOrNull()?.first ?: "")
        views.setTextViewText(R.id.finn_widget_value_1, state.value.toString())

        for (button in intArrayOf(R.id.finn_widget_minus_bg, R.id.finn_widget_plus_bg)) {
            views.setInt(button, "setColorFilter", spec.accent)
        }
        views.setOnClickPendingIntent(
            R.id.finn_widget_minus,
            tap(context, appWidgetId, FinnHomeWidgetActions.OP_MINUS),
        )
        views.setOnClickPendingIntent(
            R.id.finn_widget_plus,
            tap(context, appWidgetId, FinnHomeWidgetActions.OP_PLUS),
        )
        resetButton(context, views, appWidgetId)

        if (spec.goal > 0) {
            views.setViewVisibility(R.id.finn_widget_goal_bar, View.VISIBLE)
            val filled = ((state.value.toLong() * GOAL_SEGMENTS) / spec.goal)
                .toInt()
                .coerceIn(0, GOAL_SEGMENTS)
            for (index in 0 until GOAL_SEGMENTS) {
                views.setInt(
                    segmentIds[index],
                    "setBackgroundColor",
                    if (index < filled) spec.accent else SEGMENT_EMPTY,
                )
            }
            val goalNote = "${state.value} / ${spec.goal}"
            footer(views, if (spec.footer.isEmpty()) goalNote else "$goalNote · ${spec.footer}")
        } else {
            views.setViewVisibility(R.id.finn_widget_goal_bar, View.GONE)
            footer(views, spec.footer)
        }
        views.setOnClickPendingIntent(R.id.finn_widget_root, openApp(context, appWidgetId))
        return views
    }

    private fun listViews(
        context: Context,
        appWidgetId: Int,
        spec: FinnHomeWidgetSpec,
        state: FinnWidgetState,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.finn_home_widget)
        header(views, spec)

        for (index in 0 until MAX_ROWS) {
            val row = spec.rows.getOrNull(index)
            if (row == null) {
                views.setViewVisibility(rowIds[index], View.GONE)
                continue
            }
            views.setViewVisibility(rowIds[index], View.VISIBLE)
            views.setTextViewText(labelIds[index], row.first)

            when (spec.kind) {
                FinnWidgetKind.CHECKLIST -> {
                    val done = state.checks.getOrElse(index) { false }
                    views.setViewVisibility(markIds[index], View.VISIBLE)
                    views.setTextViewText(markIds[index], if (done) "☑" else "☐")
                    views.setTextColor(markIds[index], if (done) spec.accent.darkened() else INK)
                    views.setTextColor(labelIds[index], if (done) MUTED else LABEL)
                    views.setTextViewText(valueIds[index], "")
                    views.setViewVisibility(valueIds[index], View.GONE)
                    views.setViewVisibility(plusIds[index], View.GONE)
                }
                FinnWidgetKind.TRACKER -> {
                    views.setViewVisibility(markIds[index], View.GONE)
                    views.setTextColor(labelIds[index], LABEL)
                    views.setViewVisibility(valueIds[index], View.VISIBLE)
                    views.setTextViewText(
                        valueIds[index],
                        state.values.getOrElse(index) { 0 }.toString(),
                    )
                    views.setViewVisibility(plusIds[index], View.VISIBLE)
                    views.setInt(plusBackgroundIds[index], "setColorFilter", spec.accent)
                }
                else -> {
                    views.setViewVisibility(markIds[index], View.GONE)
                    views.setViewVisibility(plusIds[index], View.GONE)
                    views.setTextColor(labelIds[index], LABEL)
                    views.setViewVisibility(valueIds[index], View.VISIBLE)
                    views.setTextViewText(valueIds[index], row.second)
                }
            }
            if (spec.kind.interactive) {
                views.setOnClickPendingIntent(
                    rowIds[index],
                    tap(context, appWidgetId, FinnHomeWidgetActions.OP_ROW + index),
                )
            }
        }

        if (spec.kind == FinnWidgetKind.CHECKLIST) {
            val done = state.checks.count { it }
            views.setViewVisibility(R.id.finn_widget_progress_text, View.VISIBLE)
            views.setTextViewText(R.id.finn_widget_progress_text, "$done/${spec.rows.size}")
        }
        if (spec.kind.interactive) resetButton(context, views, appWidgetId)

        footer(views, spec.footer)
        // The surface opens the app; the rows and the reset control above are
        // children, so a tap on one of them is theirs and never reaches this.
        views.setOnClickPendingIntent(R.id.finn_widget_root, openApp(context, appWidgetId))
        return views
    }

    private fun header(views: RemoteViews, spec: FinnHomeWidgetSpec) {
        views.setTextViewText(R.id.finn_widget_title, spec.title)
        views.setTextColor(R.id.finn_widget_title, spec.accent.darkened())
        views.setInt(R.id.finn_widget_accent, "setBackgroundColor", spec.accent)
        views.setViewVisibility(R.id.finn_widget_accent, View.VISIBLE)
    }

    private fun footer(views: RemoteViews, text: String) {
        if (text.isEmpty()) {
            views.setViewVisibility(R.id.finn_widget_footer, View.GONE)
        } else {
            views.setViewVisibility(R.id.finn_widget_footer, View.VISIBLE)
            views.setTextViewText(R.id.finn_widget_footer, text)
        }
    }

    private fun resetButton(context: Context, views: RemoteViews, appWidgetId: Int) {
        views.setViewVisibility(R.id.finn_widget_reset, View.VISIBLE)
        views.setOnClickPendingIntent(
            R.id.finn_widget_reset,
            tap(context, appWidgetId, FinnHomeWidgetActions.OP_RESET),
        )
    }

    /** A pastel accent is too light to read as text on white; deepen it. */
    private fun Int.darkened(): Int {
        val r = ((this shr 16) and 0xFF) * 6 / 10
        val g = ((this shr 8) and 0xFF) * 6 / 10
        val b = (this and 0xFF) * 6 / 10
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    }

    /** A broadcast to the provider that applies [op] to this widget's state. */
    private fun tap(context: Context, appWidgetId: Int, op: Int): PendingIntent {
        val intent = Intent(context, FinnHomeWidgetProvider::class.java).apply {
            action = FinnHomeWidgetActions.ACTION_TAP
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(FinnHomeWidgetActions.EXTRA_OP, op)
        }
        // One request code per (widget, control), or the launcher would hand
        // every button the same PendingIntent and they would all do one thing.
        return PendingIntent.getBroadcast(
            context,
            appWidgetId * 64 + op,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
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

    private const val INK = 0xFF121212.toInt()
    private const val LABEL = 0xFF4A4A48.toInt()
    private const val MUTED = 0xFF9A9A96.toInt()
}
