/*
 * `plugins.flutter.io/url_launcher` for OpenHarmony.
 *
 * FinnAI opens web links (sources in an answer, the licences in Settings >
 * About, the report endpoint) and the model download page. HarmonyOS has no
 * `ACTION_VIEW`-style intent for arbitrary http(s) URLs, but starting the
 * browser *ability* with an explicit Want works and is the documented route.
 *
 * The Dart side computes `useWebView: true` for every http/https URL even in
 * `platformDefault` mode (method_channel_url_launcher.dart), and FinnAI never
 * asks for an in-app WebView, so `launch` always means "open in the system
 * browser".
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'plugins.flutter.io/url_launcher';

// The browser abilities HarmonyOS ships. Trying them in order and letting the
// system resolve the scheme is not possible for implicit wants, so pick the
// first that answers; if none does, report the failure honestly instead of
// silently returning false and leaving the user tapping a dead link.
const BROWSER_BUNDLES: string[] = [
  'com.huawei.hmos.browser',
  'com.huawei.browser',
  'ohos.browser',
];

export class UrlLauncherPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        UrlLauncherPlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    switch (call.method) {
      case 'canLaunch': {
        const url = call.argument('url') as string;
        result.success(UrlLauncherPlugin.isLaunchable(url));
        break;
      }
      case 'launch': {
        const url = call.argument('url') as string;
        if (!UrlLauncherPlugin.isLaunchable(url)) {
          result.success(false);
          break;
        }
        context.startAbility(UrlLauncherPlugin.browserWant(url)).then((): void => {
          result.success(true);
        }).catch((error: BusinessError): void => {
          result.success(false);
          console.error(`url_launcher: startAbility failed ${error.code} ${error.message}`);
        });
        break;
      }
      case 'closeWebView':
        // FinnAI never opens an in-app browser, so there is nothing to close.
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private static isLaunchable(url: string): boolean {
    return typeof url === 'string' && url.length > 0 &&
      (url.startsWith('http://') || url.startsWith('https://'));
  }

  private static browserWant(url: string): Want {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['ohos.want.entity.datalink'],
      uri: url,
    };
    if (BROWSER_BUNDLES.length > 0) {
      want.bundleName = BROWSER_BUNDLES[0];
    }
    return want;
  }
}