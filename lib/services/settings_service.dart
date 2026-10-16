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

  /// Preference key for the recording quality (largest output height).
  static const String keyQuality = 'recording_quality';

  /// The default output folder.
  static const String defaultOutputFolder = '~/Videos';

  /// Recording quality choices, mapped to the largest output height in pixels.
  /// 'source' (0) records at the screen's or window's own resolution.
  static const Map<String, int> qualityMaxHeights = {
    'source': 0,
    '720p': 720,
    '1080p': 1080,
    '2160p': 2160,
  };

  /// Retrieves the saved recording quality ('source' if unset or unknown).
  Future<String> getQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(keyQuality);
    return qualityMaxHeights.containsKey(value) ? value! : 'source';
  }

  /// Persists the selected recording [quality].
  Future<void> setQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyQuality, quality);
  }

  /// The largest output height for the saved quality (0 = no scaling).
  Future<int> getMaxHeight() async {
    return qualityMaxHeights[await getQuality()] ?? 0;
  }

  /// Retrieves the saved video codec preference string.
  Future<String> getCodec() async {
    final prefs = await SharedPreferences.getInstance();
    final codec = prefs.getString(keyCodec);
    // Default to h264 for high compatibility (also for unknown saved values)
    return const {'h264', 'h265', 'av1'}.contains(codec) ? codec! : 'h264';
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
    return prefs.getString(keyOutputFolder) ?? defaultOutputFolder;
  }

  /// Resolves the raw output folder path by replacing `~/` with the user's
  /// home folder.
  Future<String> getResolvedOutputFolder() async {
    return resolveFolder(await getOutputFolder(), Platform.environment['HOME']);
  }

  /// Expands a leading `~/` in [folder] using [home]. Pure, for testing.
  ///
  /// If HOME is unset (very unusual), falls back to the system temp folder
  /// rather than a hard-coded user's home directory.
  static String resolveFolder(String folder, String? home) {
    if (folder == '~' || folder.startsWith('~/')) {
      final base = (home != null && home.isNotEmpty)
          ? home
          : Directory.systemTemp.path;
      return folder == '~' ? base : folder.replaceFirst('~/', '$base/');
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
