/*
 * `finn_ai/device_actions` for OpenHarmony.
 *
 * The catalog (lib/src/features/actions/action_catalog.dart) has sixteen
 * actions. Android's MainActivity can perform most of them. HarmonyOS is
 * stricter about what a third-party app may do to the system, so this maps each
 * action onto what is genuinely reachable and answers `unavailable` for the
 * rest — the Dart executor already renders that as "Finn can't do that here",
 * which is honest. Pretending an action worked would be worse.
 *
 *   performed    the action really happened
 *   opened       the right system screen/handler was raised, but the action
 *                itself did not run
 *   unavailable  HarmonyOS offers no route from an app to this action
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common, Want } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'finn_ai/device_actions';
const TAG = 'FinnActions';

interface ActionOutcome {
  outcome: string;
  detail: string;
  error: string;
}

/** The `arguments` map the Dart executor sends with every action. */
interface ActionArgs {
  number: string;
  text: string;
  body: string;
  to: string;
  subject: string;
  query: string;
  url: string;
  name: string;
  screen: string;
  hour: number;
  minute: number;
  seconds: number;
  on: boolean;
  direction: string;
  action: string;
  milliseconds: number;
}

export class DeviceActionsPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method !== 'perform') {
          result.notImplemented();
          return;
        }
        const name = call.argument('name') as string;
        const args = call.argument('arguments') as ActionArgs;
        DeviceActionsPlugin.perform(context, name, args, result);
      },
    });
  }

  private static perform(
    context: common.UIAbilityContext,
    name: string,
    args: ActionArgs,
    result: MethodResult,
  ): void {
    switch (name) {
      // Scheme-based: the system routes these to the right handler.
      case 'dial':
        DeviceActionsPlugin.start(context, `tel:${DeviceActionsPlugin.encode(args.number)}`, result);
        break;
      case 'compose_sms':
        DeviceActionsPlugin.start(context, DeviceActionsPlugin.smsUri(args), result);
        break;
      case 'compose_email':
        DeviceActionsPlugin.start(context, DeviceActionsPlugin.mailUri(args), result);
        break;
      case 'navigate':
        DeviceActionsPlugin.start(
          context, `geo:0,0?q=${DeviceActionsPlugin.encode(args.query)}`, result);
        break;
      case 'open_url':
        DeviceActionsPlugin.start(context, `${args.url ?? ''}`, result);
        break;

      // Ability-based.
      case 'show_alarms':
        DeviceActionsPlugin.launch(context, 'com.huawei.hmos.clock', result);
        break;
      case 'open_settings':
        DeviceActionsPlugin.launch(context, 'com.huawei.hmos.settings', result);
        break;
      case 'take_photo':
        DeviceActionsPlugin.launch(context, 'com.huawei.hmos.camera', result);
        break;
      case 'open_app': {
        const bundle = DeviceActionsPlugin.resolveBundle(`${args.name ?? ''}`);
        if (bundle.length === 0) {
          result.success(DeviceActionsPlugin.outcome(
            'unavailable', '', `No HarmonyOS app known as "${args.name}".`));
          return;
        }
        DeviceActionsPlugin.launch(context, bundle, result);
        break;
      }

      // share: HarmonyOS has no cross-app share intent, but the clipboard is a
      // real, user-visible effect the next paste will pick up.
      case 'share': {
        const text = `${args.text ?? ''}`;
        if (text.length === 0) {
          result.success(DeviceActionsPlugin.outcome('failed', '', 'Nothing to share.'));
          return;
        }
        const data = pasteboard.createPlainTextData(text);
        pasteboard.getSystemPasteboard().setData(data).then((): void => {
          result.success(DeviceActionsPlugin.outcome('performed', 'clipboard', ''));
        }).catch((error: BusinessError): void => {
          result.success(DeviceActionsPlugin.outcome('failed', '', `${error.code}`));
        });
        break;
      }

      // No public HarmonyOS API lets a normal app drive these: torch and media
      // transport belong to the system UI, alarms and timers live in the Clock
      // extension, and volume/vibrate are session-scoped.
      case 'torch':
      case 'media':
      case 'volume':
      case 'vibrate':
      case 'set_alarm':
      case 'set_timer':
        result.success(DeviceActionsPlugin.outcome(
          'unavailable', '', `${name} is not controllable from a HarmonyOS app.`));
        break;

      default:
        result.success(DeviceActionsPlugin.outcome(
          'unavailable', '', `Unknown action ${name}.`));
        break;
    }
  }

  /** Hands a URI to the system handler (browser, dialer, mail, maps). */
  private static start(
    context: common.UIAbilityContext,
    uri: string,
    result: MethodResult,
  ): void {
    if (uri.length === 0 || uri.endsWith(':')) {
      result.success(DeviceActionsPlugin.outcome('failed', '', 'Missing a target for that action.'));
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uri,
      entities: ['ohos.want.entity.datalink'],
    };
    context.startAbility(want).then((): void => {
      result.success(DeviceActionsPlugin.outcome('opened', '', ''));
    }).catch((error: BusinessError): void => {
      console.error(`${TAG} startAbility(${uri}) failed ${error.code}`);
      // No handler installed for that scheme.
      result.success(DeviceActionsPlugin.outcome(
        'unavailable', '', 'No app on this device can handle that.'));
    });
  }

  private static launch(
    context: common.UIAbilityContext,
    bundleName: string,
    result: MethodResult,
  ): void {
    const want: Want = {
      bundleName: bundleName,
      abilityName: 'EntryAbility',
      action: 'ohos.want.action.main',
    };
    context.startAbility(want).then((): void => {
      result.success(DeviceActionsPlugin.outcome('opened', bundleName, ''));
    }).catch((error: BusinessError): void => {
      console.error(`${TAG} launch(${bundleName}) failed ${error.code}`);
      result.success(DeviceActionsPlugin.outcome(
        'unavailable', '', 'That app is not installed on this device.'));
    });
  }

  /**
   * HarmonyOS bundle names cannot be derived from a user-facing app name, so
   * only the apps FinnAI knows about can be opened. Anything else is reported
   * as unavailable rather than guessed at.
   */
  private static resolveBundle(appName: string): string {
    switch (appName.toLowerCase()) {
      case 'clock':
      case 'alarm':
        return 'com.huawei.hmos.clock';
      case 'settings':
        return 'com.huawei.hmos.settings';
      case 'files':
      case 'explorer':
        return 'com.huawei.hmos.filemanager';
      case 'browser':
        return 'com.huawei.hmos.browser';
      case 'camera':
        return 'com.huawei.hmos.camera';
      case 'calendar':
        return 'com.huawei.hmos.calendar';
      case 'messages':
      case 'sms':
        return 'com.huawei.hmos.mms';
      case 'mail':
      case 'email':
        return 'com.huawei.hmos.mail';
      default:
        return '';
    }
  }

  private static smsUri(args: ActionArgs): string {
    const to = `${args.to ?? ''}`;
    const body = `${args.body ?? ''}`;
    const query = to.length > 0 ? `?number=${DeviceActionsPlugin.encode(to)}` : '';
    return `sms:${to}${query}${body.length > 0 ? `&body=${DeviceActionsPlugin.encode(body)}` : ''}`;
  }

  private static mailUri(args: ActionArgs): string {
    const subject = `${args.subject ?? ''}`;
    const body = `${args.body ?? ''}`;
    const parts: string[] = [];
    if (subject.length > 0) parts.push(`subject=${DeviceActionsPlugin.encode(subject)}`);
    if (body.length > 0) parts.push(`body=${DeviceActionsPlugin.encode(body)}`);
    const to = `${args.to ?? ''}`;
    const query = parts.length > 0 ? `?${parts.join('&')}` : '';
    return `mailto:${to}${query}`;
  }

  private static encode(value: string): string {
    const text = value ?? '';
    return text.length === 0 ? '' : encodeURIComponent(text);
  }

  private static outcome(outcome: string, detail: string, error: string): ActionOutcome {
    return { outcome: outcome, detail: detail, error: error };
  }
}