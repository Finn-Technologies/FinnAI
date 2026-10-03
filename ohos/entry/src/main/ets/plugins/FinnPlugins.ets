/*
 * FinnAI OpenHarmony plugin layer.
 *
 * FinnAI depends on Flutter plugins that have no OpenHarmony implementation, so
 * `GeneratedPluginRegistrant.ets` is empty and every one of those channels
 * would raise MissingPluginException on the Dart side. This package answers the
 * *same* channels the plugins' default Dart implementations already use, so the
 * Dart code needs no fork of any plugin.
 *
 * Rules for this directory:
 *   - one file per plugin, named after the channel it answers;
 *   - mirror the upstream Dart contract exactly (channel name, method names,
 *     argument keys, reply shape). If a plugin changes, change it here too;
 *   - reply exactly once per call, and use notImplemented() for anything a
 *     plugin can call but we deliberately do not support, so the Dart side sees
 *     MissingPluginException instead of a wrong answer.
 */

import { FlutterEngine, Log } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { AudioRecordPlugin } from './AudioRecordPlugin';
import { DeviceActionsPlugin } from './DeviceActionsPlugin';
import { DeviceProfilePlugin } from './DeviceProfilePlugin';
import { FilePickerPlugin } from './FilePickerPlugin';
import { FlowPlugin } from './FlowPlugin';
import { ImagePickerPlugin } from './ImagePickerPlugin';
import { PackageInfoPlugin } from './PackageInfoPlugin';
import { PathProviderPlugin } from './PathProviderPlugin';
import { SecureKeyPlugin } from './SecureKeyPlugin';
import { SharePlugin } from './SharePlugin';
import { TtsPlugin } from './TtsPlugin';
import { UrlLauncherPlugin } from './UrlLauncherPlugin';

const TAG = 'FinnPlugins';

export class FinnPlugins {
  static register(flutterEngine: FlutterEngine, context: common.UIAbilityContext): void {
    const messenger = flutterEngine.getDartExecutor();
    // path_provider first: everything else assumes the sandbox paths resolve.
    PathProviderPlugin.register(messenger, context);
    // Plugin-facing channels (the names upstream Dart code already knows).
    UrlLauncherPlugin.register(messenger, context);
    PackageInfoPlugin.register(messenger, context);
    ImagePickerPlugin.register(messenger, context);
    FilePickerPlugin.register(messenger, context);
    SharePlugin.register(messenger, context);
    TtsPlugin.register(messenger);
    AudioRecordPlugin.register(messenger, context);
    // Finn-owned channels (finn_ai/*), mirroring the Kotlin side on Android.
    SecureKeyPlugin.register(messenger, context);
    DeviceProfilePlugin.register(messenger);
    DeviceActionsPlugin.register(messenger, context);
    FlowPlugin.register(messenger, context);
    Log.i(TAG, 'FinnAI OpenHarmony plugin channels registered');
  }
}