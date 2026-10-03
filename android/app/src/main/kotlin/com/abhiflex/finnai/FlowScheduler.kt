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
import java.util.Calendar

/**
 * Arms Flow alarms with the platform alarm service and tells the user when a
 * flow is due and cannot run by itself.
 *
 * Deliberately *inexact* ([AlarmManager.setAndAllowWhileIdle]): a morning brief
 * at "about 7:30" does not need SCHEDULE_EXACT_ALARM, which Play restricts, and
 * the OS batches the wake-up to save the battery. Alarms do not survive a
 * reboot, so the specs are kept in [FlowTriggerStore] and [FlowBootReceiver]
 * re-arms them.
 *
 * The rule for "next occurrence" mirrors `FlowSchedule.nextRun` in Dart (the
 * tested source of truth): the first local time strictly after now that
 * matches hour, minute and weekday, built from calendar fields so a daylight
 * saving change moves the flow with the wall clock.
 */
object FlowScheduler {
    const val CHANNEL_ID = "finn_flows"
    const val ACTION_RUN_FLOW = "com.abhiflex.finnai.RUN_FLOW"
    const val EXTRA_FLOW_ID = "finn_flow_id"
    const val EXTRA_TRIGGER_KEY = "finn_trigger_key"

    /** Makes the alarms and event listeners exactly what Dart asked for. */
    fun sync(context: Context, alarms: List<FlowTriggerSpec>, events: List<FlowTriggerSpec>) {
        val old = FlowTriggerStore.alarms(context)
        for (spec in old) {
            if (alarms.none { it.key == spec.key }) {
                alarmManager(context).cancel(pendingIntent(context, spec.key))
            }
        }
        FlowTriggerStore.write(context, alarms, events)
        for (spec in alarms) arm(context, spec)
        FlowTriggerService.sync(context)
    }

    fun cancelAll(context: Context) {
        for (spec in FlowTriggerStore.alarms(context)) {
            alarmManager(context).cancel(pendingIntent(context, spec.key))
        }
        FlowTriggerStore.write(context, emptyList(), emptyList())
        FlowTriggerService.sync(context)
    }

    fun rescheduleAll(context: Context) =
        FlowTriggerStore.alarms(context).forEach { arm(context, it) }

    fun arm(context: Context, spec: FlowTriggerSpec, nowMillis: Long = System.currentTimeMillis()) {
        val at = when (spec.kind) {
            "interval" -> nowMillis + spec.every.coerceAtLeast(15) * 60_000L
            else -> nextOccurrence(spec.hour, spec.minute, spec.days, nowMillis)
        } ?: return
        alarmManager(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at,
            pendingIntent(context, spec.key),
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

    /** Posts "a flow needs you". Tapping opens the app, which runs it. */
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

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Flows", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Your Flows"
            },
        )
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(context: Context, key: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            key.hashCode(),
            Intent(context, FlowAlarmReceiver::class.java).putExtra(EXTRA_TRIGGER_KEY, key),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

/** Fires when a flow's alarm is due: hands the flow on, then arms the next one. */
class FlowAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.getStringExtra(FlowScheduler.EXTRA_TRIGGER_KEY) ?: return
        val spec = FlowTriggerStore.alarm(context, key) ?: return
        FlowDispatcher.dispatch(context, spec, "schedule")
        FlowScheduler.arm(context, spec)
    }
}

/** Alarms are cleared by a reboot or an app update; this puts them back. */
class FlowBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                FlowScheduler.rescheduleAll(context)
                FlowTriggerService.sync(context)
                if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
                    FlowDispatcher.dispatchEvent(context, "deviceBooted")
                }
            }
        }
    }
}
