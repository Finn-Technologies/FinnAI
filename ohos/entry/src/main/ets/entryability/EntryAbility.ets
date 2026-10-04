import { FlutterAbility, FlutterEngine, Log } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { FinnPlugins } from '../plugins/FinnPlugins';

const TAG = 'EntryAbility';

/**
 * The ability keeps `FlutterAbility` for the lifecycle and bundle plumbing it
 * provides (autofill host, font scale, `FlutterManager` registration).
 *
 * `configureFlutterEngine` is overridden here *and* installed as a configurator
 * in `ets/pages/Index.ets`, because this fork builds the engine in more than one
 * place: `FlutterAbility.onCreate` constructs one and `FlutterEntry` constructs
 * another, and which one Dart actually talks to is decided inside the fork. A
 * handler registered on only one of them leaves every channel answering "No
 * registered handler for message". Registering on both is idempotent -- a
 * MethodChannel handler is replaced, not duplicated -- so it is correct whichever
 * engine is live.
 */
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);

    // `GeneratedPluginRegistrant` is empty: none of FinnAI's Flutter plugins
    // (flutter_secure_storage, image_picker, file_picker, url_launcher,
    // package_info_plus, flutter_tts, record) ship an OpenHarmony
    // implementation, so the Dart side falls back to each plugin's default
    // method-channel implementation. `FinnPlugins` answers those same channels,
    // plus the `finn_ai/*` channels Android implements in Kotlin.
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    FinnPlugins.register(flutterEngine, this.context);
    Log.i(TAG, 'FinnAI OpenHarmony plugin channels registered (ability engine)');
  }

  onDestroy(): void {
    Log.i(TAG, 'FinnAI EntryAbility destroyed');
    super.onDestroy();
  }
}