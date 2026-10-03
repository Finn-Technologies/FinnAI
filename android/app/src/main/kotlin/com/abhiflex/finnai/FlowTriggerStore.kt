package com.abhiflex.finnai

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * One thing that can start a flow, as Dart told us about it.
 *
 * `kind` is the Dart `FlowTriggerKind` name, so the two sides never need a
 * mapping table. [auto] says whether the flow may run by itself when this
 * fires; when it may not, the platform only tells the user it is due.
 */
data class FlowTriggerSpec(
    val flowId: String,
    val slot: Int,
    val name: String,
    val kind: String,
    val hour: Int,
    val minute: Int,
    val days: List<Int>,
    val every: Int,
    val level: Int,
    val auto: Boolean,
) {
    val key: String get() = "$flowId#$slot"

    val isAlarm: Boolean get() = kind == "timeOfDay" || kind == "interval"

    fun toJson(): JSONObject = JSONObject()
        .put("flowId", flowId)
        .put("slot", slot)
        .put("name", name)
        .put("kind", kind)
        .put("hour", hour)
        .put("minute", minute)
        .put("days", JSONArray(days))
        .put("every", every)
        .put("level", level)
        .put("auto", auto)

    companion object {
        fun fromMap(map: Map<*, *>): FlowTriggerSpec? {
            val flowId = map["flowId"] as? String ?: return null
            val kind = map["kind"] as? String ?: return null
            return FlowTriggerSpec(
                flowId = flowId,
                slot = (map["slot"] as? Number)?.toInt() ?: 0,
                name = (map["name"] as? String) ?: "Flow",
                kind = kind,
                hour = (map["hour"] as? Number)?.toInt() ?: 0,
                minute = (map["minute"] as? Number)?.toInt() ?: 0,
                days = (map["days"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList(),
                every = (map["every"] as? Number)?.toInt() ?: 0,
                level = (map["level"] as? Number)?.toInt() ?: 20,
                auto = map["auto"] == true,
            )
        }

        fun fromJson(json: JSONObject): FlowTriggerSpec {
            val days = json.optJSONArray("days")
            return FlowTriggerSpec(
                flowId = json.getString("flowId"),
                slot = json.optInt("slot", 0),
                name = json.optString("name", "Flow"),
                kind = json.getString("kind"),
                hour = json.optInt("hour", 0),
                minute = json.optInt("minute", 0),
                days = if (days == null) emptyList() else (0 until days.length()).map { days.getInt(it) },
                every = json.optInt("every", 0),
                level = json.optInt("level", 20),
                auto = json.optBoolean("auto", false),
            )
        }
    }
}

/**
 * The triggers Dart last synced, kept on the phone so alarms can be re-armed
 * after a reboot and events can be listened for with no Flutter engine running.
 */
object FlowTriggerStore {
    private const val PREFS = "finn_flow_triggers"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_EVENTS = "events"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun alarms(context: Context): List<FlowTriggerSpec> = read(context, KEY_ALARMS)

    fun events(context: Context): List<FlowTriggerSpec> = read(context, KEY_EVENTS)

    fun alarm(context: Context, key: String): FlowTriggerSpec? =
        alarms(context).firstOrNull { it.key == key }

    fun write(context: Context, alarms: List<FlowTriggerSpec>, events: List<FlowTriggerSpec>) {
        prefs(context).edit()
            .putString(KEY_ALARMS, JSONArray(alarms.map { it.toJson() }).toString())
            .putString(KEY_EVENTS, JSONArray(events.map { it.toJson() }).toString())
            .apply()
    }

    private fun read(context: Context, key: String): List<FlowTriggerSpec> {
        val raw = prefs(context).getString(key, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { FlowTriggerSpec.fromJson(array.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
