/*
 * `flutter_tts` for OpenHarmony, backed by the HarmonyOS text-to-speech engine
 * (`textToSpeech` in `@kit.CoreSpeechKit`).
 *
 * Contract details the Dart side decides for us:
 *   - `speak` sends a bare String here, not the Android {text, focus} map,
 *     because flutter_tts.dart only builds the map when Platform.isAndroid.
 *     Both shapes are accepted.
 *   - completion is delivered by the platform calling *back* into Dart on this
 *     same channel (speak.onStart / speak.onComplete / speak.onCancel /
 *     speak.onError), which is what FallbackTtsBackend waits on. Those
 *     callbacks are therefore the important part of this file.
 *
 * The HarmonyOS engine is coarser than Android's: voice, volume and speed are
 * per-utterance `extraParams`, and there is one engine per language. Options
 * are therefore remembered and applied on the next `speak`, and the calls that
 * have no HarmonyOS equivalent answer harmlessly so `initialize()` on the Dart
 * side does not throw.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { textToSpeech } from '@kit.CoreSpeechKit';

const CHANNEL = 'flutter_tts';
const TAG = 'FinnTts';

/** The `{ text, focus }` map flutter_tts builds when Platform.isAndroid. */
interface SpeakTextArgs {
  text: string;
  focus: boolean;
}

/**
 * `speak` arrives as a bare String on every non-Android platform, and as
 * `{ text, focus }` on Android. Both are accepted so a change to that Dart
 * branch cannot silently make Finn read nothing aloud.
 */
function speakText(value: Object): string {
  if (typeof value === 'string') {
    return value as string;
  }
  return (value as SpeakTextArgs).text;
}

export class TtsPlugin {
  private static channel: MethodChannel | null = null;
  private static engine: textToSpeech.TextToSpeechEngine | null = null;
  private static language = 'en-US';
  private static volume = 50;
  private static speed = 50;
  private static queueMode = 1;
  private static speaking = false;
  private static requestCounter = 0;

  static register(messenger: BinaryMessenger): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    TtsPlugin.channel = channel;
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        TtsPlugin.handle(call, result);
      },
    });
  }

  static handle(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      // No-ops with no HarmonyOS equivalent; answering keeps the Dart-side
      // `initialize()` sequence from throwing.
      case 'awaitSpeakCompletion':
      case 'awaitSynthCompletion':
      case 'setSharedInstance':
      case 'autoStopSharedSession':
      case 'clearVoice':
      case 'setSilence':
      case 'setEngine':
      case 'setPitch':
        result.success(null);
        break;

      case 'setVolume': {
        const requested: number = Number(call.args ?? 1.0);
        TtsPlugin.volume = Math.max(0, Math.min(100, Math.round(requested * 100)));
        result.success(null);
        break;
      }

      case 'setSpeechRate': {
        // flutter_tts uses 0.0-1.0 with 0.5 normal; HarmonyOS uses 0-50.
        const requested: number = Number(call.args ?? 0.5);
        TtsPlugin.speed = Math.max(0, Math.min(100, Math.round(requested * 100)));
        result.success(null);
        break;
      }

      case 'setLanguage': {
        const requested = TtsPlugin.normalizeLanguage(`${call.args ?? 'en-US'}`);
        TtsPlugin.ensureEngine(requested).then((): void => {
          result.success(1);
        }).catch((error: BusinessError): void => {
          result.success(0);
          console.error(`${TAG} setLanguage(${requested}) failed ${error.code}`);
        });
        break;
      }

      case 'isLanguageAvailable':
      case 'isLanguageInstalled': {
        const requested = TtsPlugin.normalizeLanguage(`${call.args ?? 'en-US'}`);
        // One engine per language on HarmonyOS: the one currently created is
        // the one that will speak, so that is the only language that is
        // genuinely available. `setLanguage` re-creates the engine for another.
        result.success(TtsPlugin.language === requested);
        break;
      }

      case 'getLanguages':
        result.success(TtsPlugin.engine !== null ? [TtsPlugin.language] : []);
        break;

      case 'getEngines':
        result.success(['harmonyos-system-tts']);
        break;

      case 'getDefaultEngine':
        result.success('harmonyos-system-tts');
        break;

      case 'setQueueMode':
        TtsPlugin.queueMode = Number(call.args ?? 1);
        result.success(null);
        break;

      case 'stop':
        TtsPlugin.stop((): void => {
          result.success(null);
        });
        break;

      case 'speak': {
        // flutter_tts sends a bare String off Android; accept both shapes.
        const text: string = speakText(call.args);
        TtsPlugin.speak(text).then((): void => {
          result.success(null);
        }).catch((error: BusinessError): void => {
          result.error('tts_failed', `${error.code}: ${error.message}`, null);
        });
        break;
      }

      default:
        result.notImplemented();
        break;
    }
  }

  private static async ensureEngine(language: string): Promise<void> {
    if (TtsPlugin.engine !== null && TtsPlugin.language === language) {
      return;
    }
    if (TtsPlugin.engine !== null) {
      TtsPlugin.engine.shutdown();
      TtsPlugin.engine = null;
    }
    TtsPlugin.language = language;
    const params: textToSpeech.CreateEngineParams = {
      language: language,
      person: 0,
      // 0 = online, 1 = offline. Offline keeps synthesis on the device, which
      // is the whole point of a private assistant, so prefer it and let the
      // engine fall back if no offline voice is installed.
      online: 1,
    };
    const engine = await textToSpeech.createEngine(params);
    engine.setListener({
      onStart: (requestId: string): void => {
        TtsPlugin.speaking = true;
        TtsPlugin.notify('speak.onStart', null);
      },
      onComplete: (requestId: string): void => {
        TtsPlugin.speaking = false;
        TtsPlugin.notify('speak.onComplete', null);
      },
      onStop: (requestId: string): void => {
        TtsPlugin.speaking = false;
        TtsPlugin.notify('speak.onCancel', null);
      },
      onError: (requestId: string, code: number, message: string): void => {
        TtsPlugin.speaking = false;
        TtsPlugin.notify('speak.onError', `${code}: ${message}`);
      },
    });
    TtsPlugin.engine = engine;
  }

  private static normalizeLanguage(tag: string): string {
    return tag.length === 0 ? 'en-US' : tag.replace('_', '-');
  }

  private static async speak(text: string): Promise<void> {
    await TtsPlugin.ensureEngine(TtsPlugin.language);
    const engine = TtsPlugin.engine;
    if (engine === null) {
      throw new Error('no TTS engine');
    }
    if (TtsPlugin.queueMode === 0 && TtsPlugin.speaking) {
      engine.stop();
    }
    const extra: Record<string, Object> = {
      'volume': TtsPlugin.volume,
      'speed': TtsPlugin.speed,
      'person': 0,
    };
    const params: textToSpeech.SpeakParams = {
      requestId: TtsPlugin.nextRequestId(),
      extraParams: extra,
    };
    TtsPlugin.speaking = true;
    engine.speak(text, params);
  }

  private static stop(done: () => void): void {
    const engine = TtsPlugin.engine;
    if (engine === null) {
      TtsPlugin.speaking = false;
      done();
      return;
    }
    engine.stop();
    // HarmonyOS delivers onStop asynchronously; announce the cancel here too
    // only when nothing was speaking, so a pending completion is not lost.
    if (!TtsPlugin.speaking) {
      done();
      return;
    }
    TtsPlugin.speaking = false;
    TtsPlugin.notify('speak.onCancel', null);
    done();
  }

  private static notify(method: string, argument: string | null): void {
    if (TtsPlugin.channel === null) {
      return;
    }
    TtsPlugin.channel.invokeMethod(method, argument);
  }

  private static nextRequestId(): string {
    TtsPlugin.requestCounter += 1;
    return `finn_tts_${Date.now()}_${TtsPlugin.requestCounter}`;
  }
}