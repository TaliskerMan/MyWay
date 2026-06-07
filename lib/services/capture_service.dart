import 'dart:ffi';

import '../models/recording_params.dart';

typedef MyWayInitFunc = Int32 Function();
typedef MyWayInit = int Function();

typedef MyWayStartCaptureFunc =
    Int32 Function(
      Pointer<Void>,
      Pointer<
        NativeFunction<
          Void Function(Int32, Int32, Int32, Double, Pointer<Void>)
        >
      >,
      Pointer<Void>,
    );
typedef MyWayStartCapture =
    int Function(
      Pointer<Void>,
      Pointer<
        NativeFunction<
          Void Function(Int32, Int32, Int32, Double, Pointer<Void>)
        >
      >,
      Pointer<Void>,
    );

typedef MyWayStopCaptureFunc = Int32 Function();
typedef MyWayStopCapture = int Function();

typedef MyWayTeardownFunc = Void Function();
typedef MyWayTeardown = void Function();

class CaptureService {
  late DynamicLibrary _lib;
  late MyWayInit _mywayInit;
  late MyWayStartCapture _mywayStartCapture;
  late MyWayStopCapture _mywayStopCapture;
  late MyWayTeardown _mywayTeardown;

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
    _mywayTeardown = _lib
        .lookup<NativeFunction<MyWayTeardownFunc>>('myway_teardown')
        .asFunction();
  }

  void initialize() {
    _mywayInit();
  }

  void startCapture(RecordingParams params) {
    // Basic implementation for now, pass nulls to avoid defining full FFI struct here right now
    _mywayStartCapture(nullptr, nullptr, nullptr);
  }

  void stopCapture() {
    _mywayStopCapture();
  }

  void teardown() {
    _mywayTeardown();
  }
}
