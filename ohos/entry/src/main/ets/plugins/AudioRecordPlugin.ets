/*
 * `com.llfbandit.record/messages` for OpenHarmony.
 *
 * FinnAI's speech-to-text path needs raw 16 kHz mono PCM16 frames streamed to
 * Dart, which sherpa-onnx feeds into a Whisper recogniser
 * (`lib/src/features/voice/stt/mic_source.dart` asks for
 * `RecordConfig(encoder: pcm16bits, sampleRate: 16000, numChannels: 1)`).
 * HarmonyOS's AudioCapturer delivers exactly that shape, so this bridges
 * `AudioCapturer.read` onto the plugin's per-recorder event channels.
 *
 * Contract details that matter:
 *   - the event channel name embeds a client-generated UUID, so the sink has to
 *     be created lazily, per id;
 *   - PCM events carry a bare Uint8List with no method-name envelope;
 *   - `stop` relies on stream close to flush the tail, so the data channel must
 *     end rather than just go quiet;
 *   - `getAmplitude` is polled internally once recording starts, so it must
 *     answer or the Dart side spins on the channel.
 */

import {
  BinaryMessenger,
  EventChannel,
  EventSink,
  MethodCall,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';

const METHOD_CHANNEL = 'com.llfbandit.record/messages';
const EVENT_PREFIX = 'com.llfbandit.record/events/';
const RECORD_EVENT_CHANNEL_PREFIX = 'com.llfbandit.record/eventsRecord/';
const TAG = 'FinnRecord';

/** HarmonyOS grant result for a permission the user accepted. */
const PERMISSION_GRANTED = 0;

/** `AudioCapturer.read` hands back chunks of at most this size. */
const READ_CHUNK_BYTES = 3840;

/** The subset of `RecordConfig.toMap()` FinnAI actually sends. */
interface RecordConfigArgs {
  encoder: string;
  sampleRate: number;
  numChannels: number;
}

interface RecorderState {
  capturer: audio.AudioCapturer;
  /** The sink Dart's `receiveBroadcastStream` is listening to; null until then. */
  sink: EventSink | null;
  reading: boolean;
}

export class AudioRecordPlugin {
  private static recorders: Map<string, RecorderState> = new Map();
  private static messenger: BinaryMessenger | null = null;
  private static context: common.UIAbilityContext | null = null;

  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    AudioRecordPlugin.messenger = messenger;
    AudioRecordPlugin.context = context;
    const channel = new MethodChannel(messenger, METHOD_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        AudioRecordPlugin.handle(call, result);
      },
    });
  }

  static handle(call: MethodCall, result: MethodResult): void {
    const recorderId = call.argument('recorderId') as string;
    switch (call.method) {
      case 'create':
        // The Dart AudioRecorder constructor fires this unawaited; answering is
        // all that is needed to keep an async error from escaping the zone.
        result.success(null);
        break;

      case 'hasPermission': {
        AudioRecordPlugin.ensurePermission().then((): void => {
          result.success(true);
        }).catch((): void => {
          result.success(false);
        });
        break;
      }

      case 'startStream': {
        const config = call.args as RecordConfigArgs;
        AudioRecordPlugin.registerStateStream(recorderId);
        AudioRecordPlugin.startStream(recorderId, config).then((): void => {
          result.success(null);
        }).catch((error: BusinessError): void => {
          result.error('start_failed', `${error.code}: ${error.message}`, null);
        });
        break;
      }

      case 'start':
        // Writing to a file is not used by FinnAI; it streams PCM.
        result.notImplemented();
        break;

      case 'stop':
        AudioRecordPlugin.stop(recorderId).then((): void => {
          result.success(null);
        }).catch((error: BusinessError): void => {
          result.error('stop_failed', `${error.code}: ${error.message}`, null);
        });
        break;

      case 'cancel':
      case 'dispose':
        AudioRecordPlugin.stop(recorderId).then((): void => {
          result.success(null);
        }).catch((): void => {
          result.success(null);
        });
        break;

      case 'isRecording':
        result.success(AudioRecordPlugin.isRecording(recorderId));
        break;

      case 'isPaused':
        result.success(false);
        break;

      case 'getAmplitude':
        result.success({ current: 0, max: 0 });
        break;

      case 'isEncoderSupported':
        result.success(call.argument('encoder') === 'pcm16bits');
        break;

      case 'listInputDevices':
        result.success([]);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  private static isRecording(recorderId: string): boolean {
    const state = AudioRecordPlugin.recorders.get(recorderId);
    return state !== undefined && state.reading;
  }

  private static async ensurePermission(): Promise<void> {
    const context = AudioRecordPlugin.context;
    if (context === null) {
      throw new Error('no UIAbilityContext');
    }
    const atManager = abilityAccessCtrl.createAtManager();
    const granted = await atManager.requestPermissionsFromUser(
      context, ['ohos.permission.MICROPHONE'],
    );
    if (granted.authResults[0] !== PERMISSION_GRANTED) {
      throw new Error('microphone permission denied');
    }
  }

  private static async startStream(
    recorderId: string,
    config: RecordConfigArgs,
  ): Promise<void> {
    const sampleRate = config.sampleRate > 0 ? config.sampleRate : 16000;
    const channels = config.numChannels > 0 ? config.numChannels : 1;

    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: sampleRate as audio.AudioSamplingRate,
      channels: channels as audio.AudioChannel,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    };
    const capturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
      capturerFlags: 0,
    };
    const capturer = await audio.createAudioCapturer({
      streamInfo: streamInfo,
      capturerInfo: capturerInfo,
    });

    const state: RecorderState = {
      capturer: capturer,
      sink: null,
      reading: false,
    };
    AudioRecordPlugin.recorders.set(recorderId, state);
    // Dart creates this EventChannel *after* awaiting startStream, so the
    // stream handler is registered here and the sink is captured when Dart
    // eventually sends its `listen` control message.
    AudioRecordPlugin.registerDataStream(recorderId);
    await capturer.start();
    state.reading = true;
    AudioRecordPlugin.pump(state);
  }

  /**
   * Reads in a loop and pushes each frame. `read` is one-shot per call, so the
   * tail has to be chained; `stop` flips [RecorderState.reading] to end it.
   */
  private static async pump(state: RecorderState): Promise<void> {
    const buffer = new ArrayBuffer(READ_CHUNK_BYTES);
    while (state.reading) {
      try {
        const read: ArrayBuffer = await state.capturer.read(READ_CHUNK_BYTES, false);
        const size: number = read.byteLength;
        const sink = state.sink;
        if (state.reading && sink !== null && size > 0) {
          // A bare Uint8List is what `stream.map<Uint8List>` casts to on the
          // Dart side; anything else throws there.
          sink.success(new Uint8Array(buffer, 0, size));
        }
      } catch (error) {
        const biz = error as BusinessError;
        // 63830005 = no data, the normal result when the capturer is idle.
        if (biz.code !== 63830005) {
          console.error(`${TAG} read failed ${biz.code} ${biz.message}`);
          break;
        }
      }
    }
  }

  private static async stop(recorderId: string): Promise<void> {
    const state = AudioRecordPlugin.recorders.get(recorderId);
    if (state === undefined) {
      return;
    }
    AudioRecordPlugin.recorders.delete(recorderId);
    state.reading = false;
    try {
      await state.capturer.stop();
    } catch (_) {
      // Already stopped.
    }
    try {
      await state.capturer.release();
    } catch (_) {
      // Already released.
    }
    // Ending the data stream is how Dart learns the tail is complete.
    if (state.sink !== null) {
      state.sink.endOfStream();
      state.sink = null;
    }
    AudioRecordPlugin.recorders.delete(recorderId);
  }

  private static registerDataStream(recorderId: string): void {
    const messenger = AudioRecordPlugin.messenger;
    if (messenger === null) {
      return;
    }
    const events = new EventChannel(
      messenger,
      `${RECORD_EVENT_CHANNEL_PREFIX}${recorderId}`,
    );
    events.setStreamHandler({
      onListen: (args: MethodCall, sink: EventSink): void => {
        const state = AudioRecordPlugin.recorders.get(recorderId);
        if (state !== undefined) {
          state.sink = sink;
        }
      },
      onCancel: (args: MethodCall): void => {
        const state = AudioRecordPlugin.recorders.get(recorderId);
        if (state !== undefined) {
          state.sink = null;
        }
      },
    });
  }

  private static registerStateStream(recorderId: string): void {
    const messenger = AudioRecordPlugin.messenger;
    if (messenger === null) {
      return;
    }
    const events = new EventChannel(
      messenger,
      `${EVENT_PREFIX}${recorderId}`,
    );
    events.setStreamHandler({
      onListen: (args: MethodCall, sink: EventSink): void => {
        // RecordState is `enum { pause, record, stop }`; the recorder was just
        // stopped, and this is the last event Dart will see for it.
        sink.success(2);
        sink.endOfStream();
      },
      onCancel: (args: MethodCall): void => {},
    });
  }
}