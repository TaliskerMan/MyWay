import 'package:flutter/material.dart';
import '../services/capture_service.dart';
import '../services/settings_service.dart';
import '../models/recording_params.dart';

class RecordButton extends StatefulWidget {
  final String captureMode;
  const RecordButton({super.key, required this.captureMode});

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  bool _isRecording = false;
  final _captureService = CaptureService();
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _captureService.initialize();
  }

  void _toggleRecording() async {
    if (_isRecording) {
      _captureService.stopCapture();
      setState(() => _isRecording = false);
    } else {
      final codec = await _settingsService.getCodec();
      final bitrate = await _settingsService.getBitrate();
      final outputFolder = await _settingsService.getOutputFolder();

      final params = RecordingParams(
        mode: widget.captureMode,
        codec: codec,
        videoBitrate: bitrate,
        audioNodeId: 0, // Default for now
        outputPath:
            '$outputFolder/myway_recording_${DateTime.now().millisecondsSinceEpoch}.mkv',
      );

      _captureService.startCapture(params);
      setState(() => _isRecording = true);
    }
  }

  @override
  void dispose() {
    _captureService.teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isRecording ? 80 : 100,
        height: _isRecording ? 80 : 100,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red.shade800 : Colors.red,
          borderRadius: BorderRadius.circular(_isRecording ? 20 : 50),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.5),
              blurRadius: _isRecording ? 10 : 20,
              spreadRadius: _isRecording ? 2 : 5,
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
