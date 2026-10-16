import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myway/services/portal_service.dart';
import 'package:myway/services/settings_service.dart';

/// UI settings screen allowing configuration modifications for video quality,
/// target codecs, stream bitrates, and media folders.
class SettingsScreen extends StatefulWidget {
  /// Creates a new [SettingsScreen] instance.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  // These start at the same defaults as SettingsService and are replaced by
  // the saved values as soon as they load.
  String _codec = 'h264';
  String _quality = 'source';
  int _bitrate = 20000;
  String _outputFolder = SettingsService.defaultOutputFolder;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final codec = await _settings.getCodec();
    final quality = await _settings.getQuality();
    final bitrate = await _settings.getBitrate();
    final folder = await _settings.getOutputFolder();
    if (!mounted) return;
    setState(() {
      _codec = codec;
      _quality = quality;
      _bitrate = bitrate;
      _outputFolder = folder;
    });
  }

  Future<void> _chooseFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _picking = true);
    final portal = PortalService();
    try {
      final path = await portal.pickFolder();
      if (path == null) return; // cancelled
      if (!await Directory(path).exists()) {
        messenger.showSnackBar(
          SnackBar(content: Text('That folder no longer exists: $path')),
        );
        return;
      }
      await _settings.setOutputFolder(path);
      if (mounted) setState(() => _outputFolder = path);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the folder chooser: $e')),
      );
    } finally {
      await portal.close();
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _resetFolder() async {
    await _settings.setOutputFolder(SettingsService.defaultOutputFolder);
    if (mounted) {
      setState(() => _outputFolder = SettingsService.defaultOutputFolder);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings & Media',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Video Codec'),
                  child: DropdownButton<String>(
                    value: _codec,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'h264',
                        child: Text('H.264 (AVC) - plays everywhere'),
                      ),
                      DropdownMenuItem(
                        value: 'h265',
                        child: Text('H.265 (HEVC) - smaller files'),
                      ),
                      DropdownMenuItem(
                        value: 'av1',
                        child: Text('AV1 (SVT-AV1) - needs svtav1enc'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _codec = value);
                        _settings.setCodec(value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Recording Quality',
                    helperText: 'Scales down only; never enlarges.',
                  ),
                  child: DropdownButton<String>(
                    value: _quality,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'source',
                        child: Text('Source (no scaling)'),
                      ),
                      DropdownMenuItem(
                        value: '720p',
                        child: Text('Up to 720p (HD)'),
                      ),
                      DropdownMenuItem(
                        value: '1080p',
                        child: Text('Up to 1080p (FHD)'),
                      ),
                      DropdownMenuItem(
                        value: '2160p',
                        child: Text('Up to 2160p (4K)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _quality = val);
                        _settings.setQuality(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Video Bitrate: ${_bitrate / 1000} Mbps'),
          Slider(
            value: _bitrate.toDouble().clamp(2000.0, 80000.0),
            min: 2000,
            max: 80000,
            divisions: 78,
            onChanged: (val) {
              setState(() => _bitrate = val.toInt());
            },
            onChangeEnd: (val) {
              _settings.setBitrate(val.toInt());
            },
          ),
          const SizedBox(height: 32),
          ListTile(
            title: const Text('Output Folder'),
            subtitle: Text(_outputFolder),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_outputFolder != SettingsService.defaultOutputFolder)
                  IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset to ~/Videos',
                    onPressed: _resetFolder,
                  ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Choose folder',
                  onPressed: _picking ? null : _chooseFolder,
                ),
              ],
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
