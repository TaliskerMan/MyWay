import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../models/recording_params.dart';

// Represents the native C struct MyWayCaptureParams
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

class CaptureStatus {
  final int durationSec;
  final int bitrateKbps;
  final int frameDrops;
  final double vuLevel;
  CaptureStatus(
    this.durationSec,
    this.bitrateKbps,
    this.frameDrops,
    this.vuLevel,
  );
}

// Global stream controllers to pass updates to the Flutter UI layer
final captureStatusStreamController =
    StreamController<CaptureStatus>.broadcast();
final audioMonitorStreamController = StreamController<double>.broadcast();

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

  CaptureService() {
    _lib = DynamicLibrary.open('libmyway_capture.so');
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

  void initialize() {
    _mywayInit();
  }

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

    _mywayStartCapture(structPtr);
    calloc.free(structPtr);

    // Poll status every 100ms
    _captureTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final duration = _mywayGetRecordingDuration();
      final vu = _mywayGetRecordingVu();
      captureStatusStreamController.add(CaptureStatus(duration, 0, 0, vu));
      audioMonitorStreamController.add(vu);
    });
  }

  void stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _mywayStopCapture();
  }

  void startAudioMonitor(int audioNodeId) {
    _monitorTimer?.cancel();
    _mywayStartAudioMonitor(audioNodeId);

    // Poll audio meter level every 50ms for smooth animations
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final vu = _mywayGetMonitorVu();
      audioMonitorStreamController.add(vu);
    });
  }

  void stopAudioMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _mywayStopAudioMonitor();
  }

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
    final bytes = str.codeUnits;
    for (var i = 0; i < maxLength; i++) {
      if (i < bytes.length) {
        array[i] = bytes[i];
      } else {
        array[i] = 0;
      }
    }
  }

  void setupFdExtraction(String path) {
    final ptr = path.toNativeUtf8();
    _mywaySetupFdExtraction(ptr);
    calloc.free(ptr);
  }

  int readExtractedFd() {
    return _mywayReadExtractedFd();
  }
}
