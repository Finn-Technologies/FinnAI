/*
 * `dev.fluttercommunity.plus/package_info` for OpenHarmony.
 *
 * FinnAI reads the app version in Settings, Settings > Model and in every
 * problem report, so a missing channel means three visibly wrong screens plus
 * reports with no version in them.
 *
 * `installTime`/`updateTime` must be *strings* of epoch milliseconds: the Dart
 * side runs them through `int.parse` (method_channel_package_info.dart).
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { bundleManager, common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';

const CHANNEL = 'dev.fluttercommunity.plus/package_info';

export class PackageInfoPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        PackageInfoPlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    if (call.method !== 'getAll') {
      result.notImplemented();
      return;
    }
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE,
      );
      // The module name varies between "entry" and the module declared in
      // build-profile.json5, so prefer the loaded UIAbility's own module and
      // fall back to the app-level info.
      const hapModule = info.hapModulesInfo !== undefined && info.hapModulesInfo.length > 0 ?
        info.hapModulesInfo[0] : undefined;
      const moduleName = context.abilityInfo !== undefined && context.abilityInfo.moduleName.length > 0 ?
        context.abilityInfo.moduleName : 'entry';
      const moduleInfo = hapModule !== undefined && hapModule.name === moduleName ? hapModule : undefined;

      result.success({
        appName: info.name.replace('com.abhiflex.', ''),
        packageName: info.name,
        version: info.versionName,
        buildNumber: `${info.versionCode}`,
        buildSignature: '',
        installerStore: '',
  
        installTime: `${info.installTime}`,
        updateTime: `${info.updateTime}`,
        // Not part of the plugin contract, but harmless and handy in logs.
        deviceType: deviceInfo.deviceType,
      });
    } catch (error) {
      const biz = error as BusinessError;
      result.error('package_info_failed', `getBundleInfoForSelfSync: ${biz.code} ${biz.message}`, null);
    }
  }

  /**
   * HarmonyOS reports installTime/updateTime as epoch *milliseconds* already,
   * which is what the Dart side parses; it only needs them as strings.
   */
}