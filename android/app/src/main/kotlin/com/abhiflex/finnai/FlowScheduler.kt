package com.abhiflex.finnai

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Schedules Flows with the platform alarm service and tells the user when one
 * is due.
 *
 * Deliberately *inexact* ([AlarmManager.setAndAllowWhileIdle]): a morning brief
 * at "about 7:30" does not need SCHEDULE_EXACT_ALARM, which Play restricts, and
 * the OS batches the wake-up to save the battery. Alarms do not survive a
 * reboot, so the specs are kept in SharedPreferences and [FlowBootReceiver]
 * re-arms them.
 *
 * The rule for "next occurrence" mirrors `FlowSchedule.nextRun` in Dart (the
 * tested source of truth): the first local time strictly after now that
 * matches hour, minute and weekday, built from calendar fields so a daylight
 * saving change moves the flow with the wall clock.
 */
object FlowScheduler {
    private const val PREFS = "finn_flows"
    private const val KEY_SPECS = "specs"
    const val CHANNEL_ID = "finn_flows"
    const val ACTION_RUN_FLOW = "com.abhiflex.finnai.RUN_FLOW"
    const val EXTRA_FLOW_ID = "finn_flow_id"

    data class Spec(
        val id: String,
        val name: String,
        val hour: Int,
        val minute: Int,
        val days: List<Int>,
    )

    fun schedule(context: Context, spec: Spec) {
        val specs = readSpecs(context).filter { it.id != spec.id } + spec
        writeSpecs(context, specs)
        arm(context, spec)
    }

    fun cancel(context: Context, id: String) {
        writeSpecs(context, readSpecs(context).filter { it.id != id })
        alarmManager(context).cancel(pendingIntent(context, id))
    }

    fun cancelAll(context: Context) {
        readSpecs(context).forEach { alarmManager(context).cancel(pendingIntent(context, it.id)) }
        writeSpecs(context, emptyList())
    }

    fun rescheduleAll(context: Context) = readSpecs(context).forEach { arm(context, it) }

    fun specFor(context: Context, id: String): Spec? = readSpecs(context).firstOrNull { it.id == id }

    fun arm(context: Context, spec: Spec, nowMillis: Long = System.currentTimeMillis()) {
        val at = nextOccurrence(spec.hour, spec.minute, spec.days, nowMillis) ?: return
        alarmManager(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at,
            pendingIntent(context, spec.id),
        )
    }

    /** Days are 1 = Monday .. 7 = Sunday, like Dart's DateTime.weekday. */
    fun nextOccurrence(hour: Int, minute: Int, days: List<Int>, nowMillis: Long): Long? {
        for (offset in 0..7) {
            val calendar = Calendar.getInstance()
            calendar.timeInMillis = nowMillis
            calendar.add(Calendar.DAY_OF_YEAR, offset)
            calendar.set(Calendar.HOUR_OF_DAY, hour)
            calendar.set(Calendar.MINUTE, minute)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            if (calendar.timeInMillis <= nowMillis) continue
            val weekday = ((calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            if (days.isEmpty() || days.contains(weekday)) return calendar.timeInMillis
        }
        return null
    }

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Posts "a flow is due". Tapping opens the app, which runs it. */
    fun notifyDue(context: Context, id: String, title: String, body: String) {
        if (!notificationsAllowed(context)) return
        ensureChannel(context)
        val open = Intent(context, MainActivity::class.java).apply {
            action = ACTION_RUN_FLOW
            putExtra(EXTRA_FLOW_ID, id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val tap = PendingIntent.getActivity(
            context,
            id.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(id.hashCode(), notification)
    }

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Flows", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Your scheduled Flows"
            },
        )
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(context: Context, id: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, FlowAlarmReceiver::class.java).putExtra(EXTRA_FLOW_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun readSpecs(context: Context): List<Spec> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SPECS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { index ->
                val item = array.getJSONObject(index)
                val days = item.getJSONArray("days")
                Spec(
                    item.getString("id"),
                    item.getString("name"),
                    item.getInt("hour"),
                    item.getInt("minute"),
                    (0 until days.length()).map { days.getInt(it) },
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun writeSpecs(context: Context, specs: List<Spec>) {
        val array = JSONArray()
        specs.forEach {
            array.put(
                JSONObject()
                    .put("id", it.id)
                    .put("name", it.name)
                    .put("hour", it.hour)
                    .put("minute", it.minute)
                    .put("days", JSONArray(it.days)),
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_SPECS, array.toString()).apply()
    }
}

/** Fires when a scheduled Flow is due: notifies, then arms the next occurrence. */
class FlowAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(FlowScheduler.EXTRA_FLOW_ID) ?: return
        val spec = FlowScheduler.specFor(context, id) ?: return
        FlowScheduler.notifyDue(context, id, spec.name, "Tap to run")
        FlowScheduler.arm(context, spec)
    }
}

/** Alarms are cleared by a reboot or an app update; this puts them back. */
class FlowBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> FlowScheduler.rescheduleAll(context)
        }
    }
}
