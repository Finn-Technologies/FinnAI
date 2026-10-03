import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CreateNative = Pointer<Void> Function(
  Pointer<Utf8>,
  Int32,
  Pointer<Utf8>,
  Int32,
);
typedef _Create = Pointer<Void> Function(
  Pointer<Utf8>,
  int,
  Pointer<Utf8>,
  int,
);
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);
typedef _FreeNative = Void Function(Pointer<Float>);
typedef _Free = void Function(Pointer<Float>);
typedef _InferNative = Int32 Function(
  Pointer<Void>,
  Pointer<Int64>,
  Int32,
  Pointer<Float>,
  Int64,
  Int64,
  Pointer<Float>,
  Int64,
  Int64,
  Int32,
  Float,
  Int32,
  Int32,
  Int32,
  Pointer<Pointer<Float>>,
  Pointer<Int32>,
  Pointer<Float>,
  Pointer<Utf8>,
  Int32,
);
typedef _Infer = int Function(
  Pointer<Void>,
  Pointer<Int64>,
  int,
  Pointer<Float>,
  int,
  int,
  Pointer<Float>,
  int,
  int,
  int,
  double,
  int,
  int,
  int,
  Pointer<Pointer<Float>>,
  Pointer<Int32>,
  Pointer<Float>,
  Pointer<Utf8>,
  int,
);

/// A voice style: the two tensors that make the model speak in one voice.
class SupertonicStyle {
  const SupertonicStyle({
    required this.ttl,
    required this.ttlDims,
    required this.dp,
    required this.dpDims,
  });

  final Float32List ttl;
  final List<int> ttlDims;
  final Float32List dp;
  final List<int> dpDims;
}

/// What the model's `tts.json` says about its audio, as the shim needs it.
class SupertonicConfig {
  const SupertonicConfig({
    required this.sampleRate,
    required this.chunkSize,
    required this.latentDim,
  });

  final int sampleRate;

  /// `base_chunk_size * chunk_compress_factor`.
  final int chunkSize;

  /// `ldim * chunk_compress_factor`.
  final int latentDim;

  factory SupertonicConfig.fromJson(Map<String, Object?> json) {
    final ae = json['ae']! as Map<String, Object?>;
    final ttl = json['ttl']! as Map<String, Object?>;
    final compress = (ttl['chunk_compress_factor']! as num).toInt();
    return SupertonicConfig(
      sampleRate: (ae['sample_rate']! as num).toInt(),
      chunkSize: (ae['base_chunk_size']! as num).toInt() * compress,
      latentDim: (ttl['latent_dim']! as num).toInt() * compress,
    );
  }
}

/// The compiled shim (`libfinn_tts.so`, built from `android/app/src/main/cpp`)
/// that runs the voice's four ONNX models. Not thread-safe: one isolate owns it.
class SupertonicNative {
  SupertonicNative._(DynamicLibrary lib, this._handle)
      : _destroy = lib.lookupFunction<_DestroyNative, _Destroy>(
          'finn_tts_destroy',
        ),
        _free = lib.lookupFunction<_FreeNative, _Free>('finn_tts_free'),
        _infer = lib.lookupFunction<_InferNative, _Infer>('finn_tts_infer');

  final Pointer<Void> _handle;
  final _Destroy _destroy;
  final _Free _free;
  final _Infer _infer;

  /// Loads the four models from [directory] (the folder holding the `.onnx`
  /// files). Slow: seconds.
  static SupertonicNative load(String directory, {int threads = 2}) {
    final lib = DynamicLibrary.open('libfinn_tts.so');
    final create =
        lib.lookupFunction<_CreateNative, _Create>('finn_tts_create');
    final path = directory.toNativeUtf8();
    final error = calloc<Uint8>(256).cast<Utf8>();
    try {
      final handle = create(path, threads, error, 256);
      if (handle == nullptr) {
        throw StateError('voice failed to load: ${error.toDartString()}');
      }
      return SupertonicNative._(lib, handle);
    } finally {
      malloc.free(path);
      calloc.free(error);
    }
  }

  /// Speaks one piece of text: its [ids], in [style], [steps] denoising steps.
  /// Returns the speech as -1..1 floats.
  Float32List infer({
    required List<int> ids,
    required SupertonicStyle style,
    required SupertonicConfig config,
    required int steps,
    required double speed,
  }) {
    final idPtr = calloc<Int64>(ids.length);
    final ttlPtr = calloc<Float>(style.ttl.length);
    final dpPtr = calloc<Float>(style.dp.length);
    final out = calloc<Pointer<Float>>();
    final outLength = calloc<Int32>();
    final outSeconds = calloc<Float>();
    final error = calloc<Uint8>(256).cast<Utf8>();
    try {
      idPtr.asTypedList(ids.length).setAll(0, ids);
      ttlPtr.asTypedList(style.ttl.length).setAll(0, style.ttl);
      dpPtr.asTypedList(style.dp.length).setAll(0, style.dp);
      final code = _infer(
        _handle,
        idPtr,
        ids.length,
        ttlPtr,
        style.ttlDims[1],
        style.ttlDims[2],
        dpPtr,
        style.dpDims[1],
        style.dpDims[2],
        steps,
        speed,
        config.sampleRate,
        config.chunkSize,
        config.latentDim,
        out,
        outLength,
        outSeconds,
        error,
        256,
      );
      if (code != 0) {
        throw StateError('speech failed ($code): ${error.toDartString()}');
      }
      final samples = Float32List.fromList(
        out.value.asTypedList(outLength.value),
      );
      _free(out.value);
      return samples;
    } finally {
      calloc
        ..free(idPtr)
        ..free(ttlPtr)
        ..free(dpPtr)
        ..free(out)
        ..free(outLength)
        ..free(outSeconds)
        ..free(error);
    }
  }

  void dispose() => _destroy(_handle);
}
