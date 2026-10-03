import { FlutterAbility, FlutterEngine, Log } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { FinnPlugins } from '../plugins/FinnPlugins';

const TAG = 'EntryAbility';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);

    // `GeneratedPluginRegistrant` is empty: none of FinnAI's Flutter plugins
    // (flutter_secure_storage, image_picker, file_picker, url_launcher,
    // package_info_plus, flutter_tts, record) ship an OpenHarmony
    // implementation, so the Dart side falls back to each plugin's default
    // method-channel implementation. `FinnPlugins` answers those same channels
    // in ArkTS, plus the `finn_ai/*` channels Android implements in Kotlin.
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    // `FlutterAbility` extends `UIAbability`, whose `context` is the
    // UIAbilityContext the pickers, TTS engine and permission prompts need.
    FinnPlugins.register(flutterEngine, this.context);
    Log.i(TAG, 'FinnAI OpenHarmony engine configured');
  }

  onDestroy(): void {
    Log.i(TAG, 'FinnAI EntryAbility destroyed');
    super.onDestroy();
  }
}