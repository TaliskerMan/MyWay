import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Represents the C struct
final class MyWayAudioDeviceStruct extends Struct {
  @Int32()
  external int id;

  @Array(256)
  external Array<Uint8> name;
}

/// Represents a system audio recording hardware interface or PipeWire device.
class AudioDevice {
  /// Creates an [AudioDevice] representation with [id] and [name].
  AudioDevice(this.id, this.name);

  /// Unique identifier of the device mapped from the underlying capture engine.
  final int id;

  /// User-friendly label or name of the audio device.
  final String name;
}

typedef MyWayGetAudioDevicesFunc =
    Pointer<MyWayAudioDeviceStruct> Function(Pointer<Int32>);
typedef MyWayGetAudioDevices =
    Pointer<MyWayAudioDeviceStruct> Function(Pointer<Int32>);

typedef MyWayFreeAudioDevicesFunc =
    Void Function(Pointer<MyWayAudioDeviceStruct>);
typedef MyWayFreeAudioDevices = void Function(Pointer<MyWayAudioDeviceStruct>);

/// Service layer wrapping the PipeWire/PulseAudio C bindings to query local audio input nodes.
class AudioService {
  /// Loads the native library and registers FFI functions for listing system audio devices.
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
  late DynamicLibrary _lib;
  late MyWayGetAudioDevices _getAudioDevices;
  late MyWayFreeAudioDevices _freeAudioDevices;

  /// Returns a list of all detected hardware and virtual [AudioDevice] endpoints.
  ///
  /// Invokes C FFI bindings to load structs, parses naming buffers, and automatically
  /// disposes native memory structures afterwards.
  List<AudioDevice> getAvailableDevices() {
    final countPtr = calloc<Int32>();
    final devicesPtr = _getAudioDevices(countPtr);
    final count = countPtr.value;

    final devices = <AudioDevice>[];
    if (devicesPtr != nullptr) {
      for (var index = 0; index < count; index++) {
        final ref = (devicesPtr + index).ref;
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
