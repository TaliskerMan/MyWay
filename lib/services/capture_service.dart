import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../models/recording_params.dart';

/// FFI structural layout mapping the native C-based capture parameter configuration.
final class MyWayCaptureParamsStruct extends Struct {
  @Array(32)
  external Array<Uint8> mode;

  @Array(16)
  external Array<Uint8> codec;

  @Int32()
  external int videoBitrate;

  @Uint64()
  external int videoNodeId;

  @Int32()
  external int audioNodeId;

  @Array(1024)
  external Array<Uint8> outputPath;

  @Int32()
  external int areaX;

  @Int32()
  external int areaY;

  @Int32()
  external int areaWidth;

  @Int32()
  external int areaHeight;

  @Int32()
  external int isWayland;

  @Int32()
  external int waylandFd;
}

typedef MyWayInitFunc = Int32 Function();
typedef MyWayInit = int Function();

typedef MyWayStartCaptureFunc =
    Int32 Function(Pointer<MyWayCaptureParamsStruct>);
typedef MyWayStartCapture = int Function(Pointer<MyWayCaptureParamsStruct>);

typedef MyWayStopCaptureFunc = Int32 Function();
typedef MyWayStopCapture = int Function();

typedef MyWayStartAudioMonitorFunc = Int32 Function(Int32);
typedef MyWayStartAudioMonitor = int Function(int);

typedef MyWayStopAudioMonitorFunc = Int32 Function();
typedef MyWayStopAudioMonitor = int Function();

typedef MyWayGetRecordingVuFunc = Double Function();
typedef MyWayGetRecordingVu = double Function();

typedef MyWaySetupFdExtractionFunc = Void Function(Pointer<Utf8>);
typedef MyWaySetupFdExtraction = void Function(Pointer<Utf8>);

typedef MyWayReadExtractedFdFunc = Int32 Function();
typedef MyWayReadExtractedFd = int Function();

typedef MyWayGetRecordingDurationFunc = Int32 Function();
typedef MyWayGetRecordingDuration = int Function();

typedef MyWayGetMonitorVuFunc = Double Function();
typedef MyWayGetMonitorVu = double Function();

typedef MyWayTeardownFunc = Void Function();
typedef MyWayTeardown = void Function();

/// Snapshot model holding metrics from the active recording session.
class CaptureStatus {
  /// Session duration recorded so far in seconds.
  final int durationSec;

  /// Current audio volume meter amplitude level.
  final double vuLevel;

  /// Creates a [CaptureStatus] metric packet.
  ///
  /// Note: bitrate and dropped-frame counters were removed because they were
  /// never measured (always reported 0) — exposing them implied data the
  /// pipeline did not actually provide. Re-add them only when wired to real
  /// values from the GStreamer pipeline.
  CaptureStatus(this.durationSec, this.vuLevel);
}

/// Global stream controller to broadcast capture metric snapshots to the UI.
final captureStatusStreamController =
    StreamController<CaptureStatus>.broadcast();

/// Global stream controller to broadcast live audio volume meter levels to the UI.
final audioMonitorStreamController = StreamController<double>.broadcast();

/// Main service interface driving the background audio and video recording pipelines.
///
/// Integrates with a local shared object library `libmyway_capture.so` using Dart FFI.
/// Broadcasts telemetry updates, including recording duration and audio level indicators,
/// using asynchronous streams.
class CaptureService {
  late DynamicLibrary _lib;
  late MyWayInit _mywayInit;
  late MyWayStartCapture _mywayStartCapture;
  late MyWayStopCapture _mywayStopCapture;
  late MyWayStartAudioMonitor _mywayStartAudioMonitor;
  late MyWayStopAudioMonitor _mywayStopAudioMonitor;
  late MyWayGetRecordingVu _mywayGetRecordingVu;
  late MyWayGetRecordingDuration _mywayGetRecordingDuration;
  late MyWayGetMonitorVu _mywayGetMonitorVu;
  late MyWayTeardown _mywayTeardown;
  late MyWaySetupFdExtraction _mywaySetupFdExtraction;
  late MyWayReadExtractedFd _mywayReadExtractedFd;

  Timer? _captureTimer;
  Timer? _monitorTimer;

  /// Loads the shared object library and binds all capture methods.
  CaptureService() {
    try {
      _lib = DynamicLibrary.open('libmyway_capture.so');
    } catch (e) {
      // The library is bundled at <app>/lib/libmyway_capture.so and resolved
      // via the runner's $ORIGIN/lib rpath. A failure here means a packaging
      // problem; surface it clearly instead of an opaque FFI crash.
      throw StateError(
          'MyWay: failed to load native capture library libmyway_capture.so. '
          'Ensure it is installed alongside the app (rpath \$ORIGIN/lib). '
          'Underlying error: $e');
    }
    _mywayInit = _lib
        .lookup<NativeFunction<MyWayInitFunc>>('myway_init')
        .asFunction();
    _mywayStartCapture = _lib
        .lookup<NativeFunction<MyWayStartCaptureFunc>>('myway_start_capture')
        .asFunction();
    _mywayStopCapture = _lib
        .lookup<NativeFunction<MyWayStopCaptureFunc>>('myway_stop_capture')
        .asFunction();
    _mywayStartAudioMonitor = _lib
        .lookup<NativeFunction<MyWayStartAudioMonitorFunc>>(
          'myway_start_audio_monitor',
        )
        .asFunction();
    _mywayStopAudioMonitor = _lib
        .lookup<NativeFunction<MyWayStopAudioMonitorFunc>>(
          'myway_stop_audio_monitor',
        )
        .asFunction();
    _mywayGetRecordingVu = _lib
        .lookup<NativeFunction<MyWayGetRecordingVuFunc>>(
          'myway_get_recording_vu',
        )
        .asFunction();
    _mywayGetRecordingDuration = _lib
        .lookup<NativeFunction<MyWayGetRecordingDurationFunc>>(
          'myway_get_recording_duration',
        )
        .asFunction();
    _mywayGetMonitorVu = _lib
        .lookup<NativeFunction<MyWayGetMonitorVuFunc>>('myway_get_monitor_vu')
        .asFunction();
    _mywayTeardown = _lib
        .lookup<NativeFunction<MyWayTeardownFunc>>('myway_teardown')
        .asFunction();
    _mywaySetupFdExtraction = _lib
        .lookup<NativeFunction<MyWaySetupFdExtractionFunc>>('myway_setup_fd_extraction')
        .asFunction();
    _mywayReadExtractedFd = _lib
        .lookup<NativeFunction<MyWayReadExtractedFdFunc>>('myway_read_extracted_fd')
        .asFunction();
  }

  /// Initializes the native capturing backend.
  void initialize() {
    _mywayInit();
  }

  /// Commences a new desktop screen and audio capture session.
  ///
  /// Allocates C-compatible parameters memory using [RecordingParams], dispatches
  /// the FFI start invocation, and runs a periodic timer to poll metrics.
  void startCapture(RecordingParams params) {
    _captureTimer?.cancel();

    final structPtr = calloc<MyWayCaptureParamsStruct>();
    final struct = structPtr.ref;

    _writeStringToNativeArray(struct.mode, params.mode, 32);
    _writeStringToNativeArray(struct.codec, params.codec, 16);
    struct.videoBitrate = params.videoBitrate;
    struct.videoNodeId = params.videoNodeId;
    struct.audioNodeId = params.audioNodeId;
    _writeStringToNativeArray(struct.outputPath, params.outputPath, 1024);
    struct.areaX = params.areaX;
    struct.areaY = params.areaY;
    struct.areaWidth = params.areaWidth;
    struct.areaHeight = params.areaHeight;
    struct.isWayland = params.isWayland ? 1 : 0;
    struct.waylandFd = params.waylandFd;

    // Ownership contract: myway_start_capture() consumes every field of the
    // params struct synchronously (it builds the GStreamer pipeline description
    // up front and copies all strings/ints before returning; the recording
    // thread it spawns receives NULL user-data, not this pointer). It is
    // therefore safe to free the struct immediately after the call returns.
    _mywayStartCapture(structPtr);
    calloc.free(structPtr);

    // Poll status every 100ms
    _captureTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final duration = _mywayGetRecordingDuration();
      final vu = _mywayGetRecordingVu();
      captureStatusStreamController.add(CaptureStatus(duration, vu));
      audioMonitorStreamController.add(vu);
    });
  }

  /// Stops the active capture session and cancels the metrics poll timers.
  void stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _mywayStopCapture();
  }

  /// Begins live monitoring of input decibel levels on [audioNodeId] without recording.
  void startAudioMonitor(int audioNodeId) {
    _monitorTimer?.cancel();
    _mywayStartAudioMonitor(audioNodeId);

    // Poll audio meter level every 50ms for smooth animations
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final vu = _mywayGetMonitorVu();
      audioMonitorStreamController.add(vu);
    });
  }

  /// Stops the background audio monitoring timer.
  void stopAudioMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _mywayStopAudioMonitor();
  }

  /// Shuts down the background pipelines and frees loaded FFI resource hooks.
  void teardown() {
    _captureTimer?.cancel();
    _monitorTimer?.cancel();
    _mywayTeardown();
  }

  void _writeStringToNativeArray(
    Array<Uint8> array,
    String str,
    int maxLength,
  ) {
    final bytes = encodeForNativeBuffer(str, maxLength);
    for (var i = 0; i < maxLength; i++) {
      array[i] = i < bytes.length ? bytes[i] : 0;
    }
  }

  /// Encodes [str] as UTF-8 for a fixed C `char[maxLength]` buffer.
  ///
  /// Previously this used `str.codeUnits` (UTF-16 code units), which corrupted
  /// any non-ASCII output path (accents, CJK, emoji — common under `~/Videos`).
  /// Now it encodes UTF-8, truncates to `maxLength - 1` bytes so there is always
  /// room for a terminator, and the returned list never includes the trailing
  /// NUL (the caller zero-fills the remainder). Pure + testable.
  static List<int> encodeForNativeBuffer(String str, int maxLength) {
    final encoded = utf8.encode(str);
    if (encoded.length <= maxLength - 1) return encoded;
    // Truncate without splitting a multi-byte UTF-8 sequence.
    var end = maxLength - 1;
    while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
      end--; // back up over UTF-8 continuation bytes
    }
    return encoded.sublist(0, end);
  }

  /// Configures PipeWire file descriptor extraction from the portal handle at [path].
  void setupFdExtraction(String path) {
    final ptr = path.toNativeUtf8();
    _mywaySetupFdExtraction(ptr);
    calloc.free(ptr);
  }

  /// Reads the file descriptor value returned by the extraction routine.
  int readExtractedFd() {
    return _mywayReadExtractedFd();
  }
}
