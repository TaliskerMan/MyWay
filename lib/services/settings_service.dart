import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyCodec = 'video_codec';
  static const String keyBitrate = 'video_bitrate';
  static const String keyOutputFolder = 'output_folder';

  Future<String> getCodec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCodec) ??
        'h264'; // Default to h264 for high compatibility
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

  Future<String> getResolvedOutputFolder() async {
    final folder = await getOutputFolder();
    if (folder.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '/home/freecode';
      return folder.replaceFirst('~/', '$home/');
    }
    return folder;
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

  Future<int> getAudioDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('audio_device_id') ?? -1;
  }

  Future<void> setAudioDeviceId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('audio_device_id', id);
  }
}
