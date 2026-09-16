package com.abhiflex.finnai

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import java.io.File
import org.json.JSONObject

/**
 * A home-screen widget's content, as written by Dart.
 *
 * Deliberately tiny: `RemoteViews` can only show text and colour, so anything
 * richer lives in the mini-app runtime instead.
 */
data class FinnHomeWidgetSpec(
    val title: String,
    val accent: Int,
    val rows: List<Pair<String, String>>,
    val footer: String,
)

/**
 * Locates and reads the JSON spec behind each placed widget.
 *
 * The provider runs with the Flutter engine stopped, so nothing here may depend
 * on Dart having been started. Dart writes `<filesDir>/creations/home_widgets/
 * <creationId>.json`; this class maps a launcher-assigned widget id onto one of
 * those files, and can reconstruct the path from `filesDir` alone if the
 * mapping is lost (for example after a backup restore).
 */
object FinnHomeWidgetStore {
    private const val PREFS = "finn_home_widgets"
    private const val KEY_PENDING_SPEC = "pending_spec_path"
    private const val KEY_PENDING_LABEL = "pending_label"
    private const val KEY_SPEC_PREFIX = "spec_path_"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Records the spec that the next widget to appear should adopt.
     *
     * Android assigns a widget id only after the pin is accepted, and the
     * provider's `onUpdate` receives no extras from the pin request, so the
     * hand-off goes through a single staged spec.
     */
    fun stagePending(context: Context, specPath: String, label: String) {
        prefs(context).edit()
            .putString(KEY_PENDING_SPEC, specPath)
            .putString(KEY_PENDING_LABEL, label)
            .apply()
    }

    /**
     * Binds a spec to [appWidgetId], claiming the staged spec if one waits.
     *
     * Returns null when no spec is associated with the widget — for example
     * after the user cleared app data — in which case the renderer falls back
     * to a prompt rather than showing stale content. The spec filename is the
     * creation id, which the widget id cannot reconstruct, so the stored
     * mapping is the only source of truth.
     */
    fun claim(context: Context, appWidgetId: Int): String? {
        val store = prefs(context)
        store.getString(KEY_SPEC_PREFIX + appWidgetId, null)?.let { return it }

        val staged = store.getString(KEY_PENDING_SPEC, null)
        if (staged.isNullOrBlank()) return null

        store.edit()
            .putString(KEY_SPEC_PREFIX + appWidgetId, staged)
            .remove(KEY_PENDING_SPEC)
            .remove(KEY_PENDING_LABEL)
            .apply()
        return staged
    }

    fun forget(context: Context, appWidgetIds: IntArray) {
        val editor = prefs(context).edit()
        for (id in appWidgetIds) {
            editor.remove(KEY_SPEC_PREFIX + id)
        }
        editor.apply()
    }

    /** Reads [appWidgetId]'s spec, or null when nothing is stored for it. */
    fun specFor(context: Context, appWidgetId: Int): FinnHomeWidgetSpec? {
        val path = claim(context, appWidgetId) ?: return null
        val file = File(path)
        if (!file.exists()) return null
        return try {
            val json = JSONObject(file.readText())
            val rowsJson = json.optJSONArray("rows")
            val rows = ArrayList<Pair<String, String>>()
            if (rowsJson != null) {
                for (index in 0 until rowsJson.length()) {
                    val row = rowsJson.optJSONObject(index) ?: continue
                    val label = row.optString("label").trim()
                    if (label.isEmpty()) continue
                    rows.add(label to row.optString("value").trim())
                }
            }
            FinnHomeWidgetSpec(
                title = json.optString("title").trim().ifEmpty { "Finn AI" },
                accent = json.optInt("accent", DEFAULT_ACCENT),
                rows = rows,
                footer = json.optString("footer").trim(),
            )
        } catch (_: Exception) {
            // A malformed spec must not blank the launcher widget.
            null
        }
    }

    fun placedWidgetIds(context: Context): IntArray =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, FinnHomeWidgetProvider::class.java))

    /** Mint green, matching `MiniAppAccent.mint` in the Dart palette. */
    const val DEFAULT_ACCENT = 0xFF7DFFCD.toInt()
}
