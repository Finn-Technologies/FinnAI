import { FlutterEngine, FlutterEntry, FlutterPage, FlutterView, Log } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { FinnPlugins } from '../plugins/FinnPlugins';

const TAG = 'Index';

@Entry
@Component
struct Index {
  private flutterEntry?: FlutterEntry;
  private flutterView?: FlutterView;

  aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext;
    this.flutterEntry = new FlutterEntry(context);

    // This is where FinnAI's platform channels get registered.
    //
    // The engine is created by FlutterEntry from *this page*, not by
    // EntryAbility's FlutterAbility lifecycle, so overriding
    // `configureFlutterEngine` on the ability never runs. Registering there
    // left every channel unanswered: hilog showed "No registered handler for
    // message" for `plugins.flutter.io/path_provider`, `flutter_tts` and
    // `com.llfbandit.record/messages`, and the ArkTS shims in
    // `ets/plugins/` were dead code. `path_provider` kept working only because
    // OpenHarmonyPathProvider falls back to hard-coded sandbox paths, which hid
    // the failure.
    //
    // The configurator has to be installed before `aboutToAppear()`, because
    // that is what builds the engine it is later called with.
    this.flutterEntry.setFlutterEngineConfigurator({
      configureFlutterEngine: (flutterEngine: FlutterEngine): void => {
        // `GeneratedPluginRegistrant` is empty: none of FinnAI's Flutter
        // plugins ship an OpenHarmony implementation, so the Dart side falls
        // back to each plugin's default method-channel implementation.
        // `FinnPlugins` answers those same channels, plus the `finn_ai/*`
        // channels Android implements in Kotlin.
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        FinnPlugins.register(flutterEngine, context);
        Log.i(TAG, 'FinnAI OpenHarmony plugin channels registered');
      },
      cleanUpFlutterEngine: (flutterEngine: FlutterEngine): void => {
      },
    });

    this.flutterEntry.aboutToAppear();
    this.flutterView = this.flutterEntry.getFlutterView();
  }

  aboutToDisappear() {
    this.flutterEntry?.aboutToDisappear();
  }

  onPageShow() {
    this.flutterEntry?.onPageShow();
  }

  onPageHide() {
    this.flutterEntry?.onPageHide();
  }

  build() {
    Column() {
      FlutterPage({ viewId: this.flutterView?.getId() })
        .width('100%')
        .height('100%')
    }
  }
}