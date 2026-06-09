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

typedef MyWayFreeAudioDevicesFunc =
    Void Function(Pointer<MyWayAudioDeviceStruct>);
typedef MyWayFreeAudioDevices = void Function(Pointer<MyWayAudioDeviceStruct>);

class AudioService {
  late DynamicLibrary _lib;
  late MyWayGetAudioDevices _getAudioDevices;
  late MyWayFreeAudioDevices _freeAudioDevices;

  AudioService() {
    _lib = DynamicLibrary.open('libmyway_capture.so');
    _getAudioDevices = _lib
        .lookup<NativeFunction<MyWayGetAudioDevicesFunc>>(
          'myway_get_audio_devices',
        )
        .asFunction();
    _freeAudioDevices = _lib
        .lookup<NativeFunction<MyWayFreeAudioDevicesFunc>>(
          'myway_free_audio_devices',
        )
        .asFunction();
  }

  List<AudioDevice> getAvailableDevices() {
    final countPtr = calloc<Int32>();
    final devicesPtr = _getAudioDevices(countPtr);
    final count = countPtr.value;

    final List<AudioDevice> devices = [];
    if (devicesPtr != nullptr) {
      for (var i = 0; i < count; i++) {
        final ref = (devicesPtr + i).ref;
        final charCodes = <int>[];
        for (var j = 0; j < 256; j++) {
          final char = ref.name[j];
          if (char == 0) break;
          charCodes.add(char);
        }
        final name = String.fromCharCodes(charCodes);
        devices.add(AudioDevice(ref.id, name));
      }
      _freeAudioDevices(devicesPtr);
    }

    calloc.free(countPtr);
    return devices;
  }
}
