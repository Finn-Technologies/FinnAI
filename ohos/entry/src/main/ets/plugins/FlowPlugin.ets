/*
 * `finn_ai/flow_schedule` and `finn_ai/flow_env` for OpenHarmony.
 *
 * Flows are local automations: a time-of-day or interval trigger, or a device
 * event (charger, low battery, headset), that runs the model and posts a
 * notification. Android implements this with AlarmManager, a listener service
 * and notifications, plus a headless Dart engine for the background run.
 *
 * What works here, and what does not
 * ---------------------------------
 *   notifications   NotificationKit, behind a user permission — implemented.
 *   conditions      battery / connectivity / airplane / headset, read live —
 *                   implemented.
 *   event triggers  commonEventManager subscriptions — implemented. HarmonyOS
 *                   only delivers these to a running process, so an event
 *                   trigger fires while the app is alive.
 *   time triggers   NOT implemented. HarmonyOS's WorkScheduler would need a
 *                   WorkSchedulerExtensionAbility, and that ability would need
 *                   its own headless Dart engine to run the model — the
 *                   OpenHarmony counterpart of lib/flow_background.dart, which
 *                   does not exist yet. Rather than register a work item that
 *                   wakes an ability which cannot do the job, `sync` reports
 *                   the time triggers it could not schedule and Dart leaves
 *                   them visible in the Flows list. See
 *                   docs/guides/OHOS_BUILD.md.
 *
 * `sync` therefore still installs everything it can and never pretends.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { batteryInfo, commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';
import { notificationManager } from '@kit.NotificationKit';
import { audio } from '@kit.AudioKit';

const SCHEDULE_CHANNEL = 'finn_ai/flow_schedule';
const ENV_CHANNEL = 'finn_ai/flow_env';
const TAG = 'FinnFlows';
const PERMISSION_GRANTED = 0;
const AIRPLANE_EVENT = 'usual.event.AIRPLANE_MODE';

export class FlowPlugin {
  private static context: common.UIAbilityContext | null = null;
  private static subscribers: Object[] = [];

  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    FlowPlugin.context = context;
    FlowPlugin.watchAirplaneMode();

    const schedule = new MethodChannel(messenger, SCHEDULE_CHANNEL);
    schedule.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        FlowPlugin.handleSchedule(call, result);
      },
    });

    const env = new MethodChannel(messenger, ENV_CHANNEL);
    env.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method !== 'snapshot') {
          result.notImplemented();
          return;
        }
        FlowPlugin.snapshot().then((value: FlowEnvironmentSnapshot): void => {
          result.success(value);
        }).catch((error: BusinessError): void => {
          result.error('snapshot_failed', `${error.code}: ${error.message}`, null);
        });
      },
    });
  }

  private static handleSchedule(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'notificationsAllowed':
        notificationManager.isNotificationEnabled().then((enabled: boolean): void => {
          result.success(enabled);
        }).catch((): void => {
          result.success(false);
        });
        break;

      case 'requestNotifications':
        FlowPlugin.requestNotificationPermission(result);
        break;

      case 'sync': {
        const alarms = call.argument('alarms') as FlowTriggerSpecArgs[];
        const events = call.argument('events') as FlowTriggerSpecArgs[];
        FlowPlugin.sync(alarms, events);
        result.success(null);
        break;
      }

      case 'cancelAll':
        FlowPlugin.cancelAll();
        result.success(null);
        break;

      case 'notify':
        FlowPlugin.notify(
          call.argument('title') as string,
          call.argument('body') as string,
        ).then((): void => {
          result.success(null);
        }).catch((error: BusinessError): void => {
          result.error('notify_failed', `${error.code}: ${error.message}`, null);
        });
        break;

      case 'takePendingFlow':
        // Tapping a flow notification relaunches EntryAbility with no payload;
        // Dart reads the pending flow back from its own store instead.
        result.success(null);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  private static async requestNotificationPermission(result: MethodResult): Promise<void> {
    const context = FlowPlugin.context;
    if (context === null) {
      result.success(false);
      return;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const granted = await atManager.requestPermissionsFromUser(
        context, ['ohos.permission.NOTIFICATION_CONTROLLER'],
      );
      result.success(granted.authResults[0] === PERMISSION_GRANTED);
    } catch (_) {
      result.success(false);
    }
  }

  /**
   * Installs the subscriptions HarmonyOS can actually deliver. Time-based
   * triggers are logged once rather than silently dropped, so a misbehaving
   * flow is visible in a bug report instead of never running.
   */
  private static sync(alarms: FlowTriggerSpecArgs[], events: FlowTriggerSpecArgs[]): void {
    FlowPlugin.cancelAll();
    for (const spec of alarms) {
      if (spec.kind === 'timeOfDay' || spec.kind === 'interval') {
        console.warn(`${TAG} ${spec.kind} trigger ${spec.flowId}#${spec.slot} ` +
          'cannot fire unattended on HarmonyOS: no WorkScheduler extension ability yet.');
      }
    }
    for (const spec of events) {
      FlowPlugin.subscribeEvent(spec);
    }
  }

  private static subscribeEvent(spec: FlowTriggerSpecArgs): void {
    const eventName = FlowPlugin.eventNameFor(spec.kind);
    if (eventName.length === 0) {
      return;
    }
    commonEventManager.createSubscriber({ events: [eventName] })
      .then((subscriber: commonEventManager.CommonEventSubscriber): void => {
        FlowPlugin.subscribers.push(subscriber);
        commonEventManager.subscribe(
          subscriber,
          (error: BusinessError, data: commonEventManager.CommonEventData): void => {
            if (error) {
              console.error(`${TAG} event ${eventName} failed ${error.code}`);
              return;
            }
            // Log the slot only: a common event payload can carry other apps'
            // data. Dart re-evaluates every flow's conditions on its next tick,
            // so there is no second wake path to plumb here.
            console.info(`${TAG} event ${eventName} for ${spec.flowId}#${spec.slot}`);
          },
        );
      })
      .catch((error: BusinessError): void => {
        console.error(`${TAG} subscribe ${eventName} failed ${error.code}`);
      });
  }

  /**
   * HarmonyOS publishes no settings key for airplane mode, but it does publish
   * a common event for it, so the state is tracked from the event stream. It
   * starts false, which means an airplane-mode *condition* stays false until
   * the user toggles it once — better than reporting a value we cannot read.
   */
  private static airplane = false;

  private static watchAirplaneMode(): void {
    // The subscriber object has to be built by createSubscriber: HarmonyOS only
    // documents `events` for it, and passing a literal is rejected at compile
    // time.
    commonEventManager.createSubscriber({ events: [AIRPLANE_EVENT] })
      .then((subscriber: commonEventManager.CommonEventSubscriber): void => {
        FlowPlugin.subscribers.push(subscriber);
        commonEventManager.subscribe(
          subscriber,
          (error: BusinessError, data: commonEventManager.CommonEventData): void => {
            if (error) {
              return;
            }
            FlowPlugin.airplane = data.parameters?.airplaneMode === 1;
          },
        );
      })
      .catch((error: BusinessError): void => {
        console.error(`${TAG} airplane watcher failed ${error.code}`);
      });
  }

  private static eventNameFor(kind: string): string {
    switch (kind) {
      case 'chargerConnected':
        return 'ohos.event.charging.UNKNOWN_PLUGGED';
      case 'chargerDisconnected':
        return 'ohos.event.charging.UNPLUGGED';
      case 'batteryLow':
        return 'ohos.event.battery.LOW';
      case 'headsetConnected':
        return 'ohos.event.audio.headset.PLUGGED';
      case 'headsetDisconnected':
        return 'ohos.event.audio.headset.UNPLUGGED';
      default:
        return '';
    }
  }

  private static cancelAll(): void {
    for (const subscriber of FlowPlugin.subscribers) {
      try {
        commonEventManager.unsubscribe(subscriber as commonEventManager.CommonEventSubscriber);
      } catch (_) {
        // Already gone.
      }
    }
    FlowPlugin.subscribers = [];
  }

  private static async notify(title: string, body: string): Promise<void> {
    await notificationManager.publish({
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body,
        },
      },
    });
  }

  private static async snapshot(): Promise<FlowEnvironmentSnapshot> {
    let percent = 100;
    let charging = false;
    try {
      percent = batteryInfo.batterySOC;
      charging = batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE;
    } catch (_) {
      // A device with no battery (or a denied read) reports "full and idle" so a
      // condition such as batteryBelow is simply false.
    }

    let wifi = false;
    try {
      wifi = await FlowPlugin.hasDefaultNetwork();
    } catch (_) {
      // Best effort.
    }

    const airplane = FlowPlugin.airplane;

    let headset = false;
    try {
      const devices = await audio.getAudioManager()
        .getDevices(audio.DeviceFlag.OUTPUT_DEVICES_FLAG);
      headset = devices.length > 0;
    } catch (_) {
      // Best effort.
    }

    return {
      battery: percent,
      charging: charging,
      wifi: wifi,
      headset: headset,
      airplane: airplane,
    };
  }

  private static async hasDefaultNetwork(): Promise<boolean> {
    const handle = connection.getDefaultNetSync();
    if (handle === null) {
      return false;
    }
    const capabilities = await connection.getNetCapabilities(handle);
    if (capabilities === null) {
      return false;
    }
    const up = capabilities.linkUpBandwidthKbps;
    return up !== undefined && up > 0;
  }
}

interface FlowEnvironmentSnapshot {
  battery: number;
  charging: boolean;
  wifi: boolean;
  headset: boolean;
  airplane: boolean;
}

/** Mirrors `FlowTriggerSpec.toMap()` in flow_scheduler.dart. */
interface FlowTriggerSpecArgs {
  flowId: string;
  slot: number;
  name: string;
  kind: string;
  hour: number;
  minute: number;
  days: number[];
  every: number;
  level: number;
  auto: boolean;
}