import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Service interface managing local persistent user settings via SharedPreferences.
class SettingsService {
  /// Preference key for the target video codec.
  static const String keyCodec = 'video_codec';

  /// Preference key for the target video bitrate.
  static const String keyBitrate = 'video_bitrate';

  /// Preference key for the target destination storage directory.
  static const String keyOutputFolder = 'output_folder';

  /// Retrieves the saved video codec preference string.
  Future<String> getCodec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCodec) ??
        'h264'; // Default to h264 for high compatibility
  }

  /// Persists the selected video codec [codec].
  Future<void> setCodec(String codec) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCodec, codec);
  }

  /// Retrieves the saved video bitrate preference.
  Future<int> getBitrate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyBitrate) ?? 20000;
  }

  /// Persists the selected video [bitrate] preference.
  Future<void> setBitrate(int bitrate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBitrate, bitrate);
  }

  /// Retrieves the raw output folder path.
  Future<String> getOutputFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyOutputFolder) ?? '~/Videos';
  }

  /// Resolves the raw output folder path by replacing `~/` with the user home environment path.
  Future<String> getResolvedOutputFolder() async {
    final folder = await getOutputFolder();
    if (folder.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '/home/freecode';
      return folder.replaceFirst('~/', '$home/');
    }
    return folder;
  }

  /// Persists the selected output folder [path].
  Future<void> setOutputFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOutputFolder, path);
  }

  /// Retrieves whether file-backed logging is enabled.
  Future<bool> getLoggingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logging_enabled') ?? false;
  }

  /// Toggles the active logging state configuration flag.
  Future<void> setLoggingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);
  }

  /// Retrieves the saved audio device ID node.
  Future<int> getAudioDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('audio_device_id') ?? -1;
  }

  /// Persists the selected audio device [id] node.
  Future<void> setAudioDeviceId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('audio_device_id', id);
  }
}
