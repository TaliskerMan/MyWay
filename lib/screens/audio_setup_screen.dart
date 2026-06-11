import 'package:flutter/material.dart';
import '../widgets/audio_meter.dart';
import '../services/settings_service.dart';

class AudioSetupScreen extends StatefulWidget {
  const AudioSetupScreen({super.key});

  @override
  State<AudioSetupScreen> createState() => _AudioSetupScreenState();
}

class _AudioSetupScreenState extends State<AudioSetupScreen> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Audio Setup',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.mic, color: Colors.teal, size: 32),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Ensure your microphone is correctly working before recording. '
            'Speak into your microphone and check if the meter reacts.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: 300,
              child: AudioMeter(
                onDeviceChanged: (device) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      if (device != null) {
                        SettingsService().setAudioDeviceId(device.id);
                      }
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
