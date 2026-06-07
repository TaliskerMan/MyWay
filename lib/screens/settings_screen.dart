import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/recent_recordings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  String _codec = 'h265';
  String _quality = '1080p';
  int _bitrate = 20000;
  String _outputFolder = '~/Videos';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _codec = await _settings.getCodec();
    _bitrate = await _settings.getBitrate();
    _outputFolder = await _settings.getOutputFolder();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                        value: 'h265',
                        child: Text('H.265 (HEVC)'),
                      ),
                      DropdownMenuItem(
                        value: 'h264',
                        child: Text('H.264 (AVC)'),
                      ),
                      DropdownMenuItem(
                        value: 'av1',
                        child: Text('AV1 (SVT-AV1)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _codec = val);
                        _settings.setCodec(val);
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
                  ),
                  child: DropdownButton<String>(
                    value: _quality,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: '720p', child: Text('720p (HD)')),
                      DropdownMenuItem(
                        value: '1080p',
                        child: Text('1080p (FHD)'),
                      ),
                      DropdownMenuItem(
                        value: '2160p',
                        child: Text('2160p (4K)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _quality = val);
                        // Save quality settings here if needed
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
            value: _bitrate.toDouble(),
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
            trailing: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () {
                // Implement folder picker
              },
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 48),
          const Text(
            'Recorded Videos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: RecentRecordings(), // Resuing the widget we already have
          ),
        ],
      ),
    );
  }
}
