import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyCodec = 'video_codec';
  static const String keyBitrate = 'video_bitrate';
  static const String keyOutputFolder = 'output_folder';

  Future<String> getCodec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCodec) ?? 'h265';
  }

  Future<void> setCodec(String codec) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCodec, codec);
  }

  Future<int> getBitrate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyBitrate) ?? 20000;
  }

  Future<void> setBitrate(int bitrate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBitrate, bitrate);
  }

  Future<String> getOutputFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyOutputFolder) ?? '~/Videos';
  }

  Future<void> setOutputFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOutputFolder, path);
  }

  Future<bool> getLoggingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logging_enabled') ?? false;
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);
  }
}
