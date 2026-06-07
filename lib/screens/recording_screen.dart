import 'package:flutter/material.dart';
import '../widgets/audio_meter.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  String _captureMode = 'fullscreen';
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Left: App name + space + myway.png
                Row(
                  children: [
                    const Text(
                      'MyWay',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Image.asset(
                      'assets/myway.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                const Text(
                  'Select Recording Type',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Mode Buttons
                Row(
                  children: [
                    _buildModeButton(
                      'Full Screen',
                      'fullscreen',
                      Icons.monitor,
                    ),
                    const SizedBox(width: 16),
                    _buildModeButton('Window', 'window', Icons.window),
                    const SizedBox(width: 16),
                    _buildModeButton('Area', 'area', Icons.crop),
                  ],
                ),
                const Spacer(),
                // Record & Stop Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRecording
                          ? null
                          : () {
                              setState(() {
                                _isRecording = true;
                              });
                            },
                      icon: const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Record',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    ElevatedButton.icon(
                      onPressed: !_isRecording
                          ? null
                          : () {
                              setState(() {
                                _isRecording = false;
                              });
                            },
                      icon: const Icon(Icons.stop, color: Colors.white),
                      label: const Text(
                        'Stop',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 40),
          // Right side vertical VU meter and dropdown
          const SizedBox(width: 150, child: AudioMeter()),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, String value, IconData icon) {
    final isSelected = _captureMode == value;
    return InkWell(
      onTap: () {
        setState(() {
          _captureMode = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade700,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.teal : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.teal : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
