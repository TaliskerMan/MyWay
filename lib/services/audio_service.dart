import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Represents the C struct
final class MyWayAudioDeviceStruct extends Struct {
  @Int32()
  external int id;

  @Array(256)
  external Array<Uint8> name;
}

class AudioDevice {
  final int id;
  final String name;

  AudioDevice(this.id, this.name);
}

typedef MyWayGetAudioDevicesFunc =
    Pointer<MyWayAudioDeviceStruct> Function(Pointer<Int32>);
typedef MyWayGetAudioDevices =
    Pointer<MyWayAudioDeviceStruct> Function(Pointer<Int32>);

class AudioService {
  late DynamicLibrary _lib;
  late MyWayGetAudioDevices _getAudioDevices;

  AudioService() {
    _lib = DynamicLibrary.open('libmyway_capture.so');
    _getAudioDevices = _lib
        .lookup<NativeFunction<MyWayGetAudioDevicesFunc>>(
          'myway_get_audio_devices',
        )
        .asFunction();
  }

  List<AudioDevice> getAvailableDevices() {
    final countPtr = calloc<Int32>();
    _getAudioDevices(countPtr); // Use it
    // int count = countPtr.value;
    calloc.free(countPtr);

    // Placeholder
    return [AudioDevice(0, 'Default Microphone')];
  }
}
