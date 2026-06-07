import 'package:flutter/material.dart';

class AudioMeter extends StatefulWidget {
  const AudioMeter({super.key});

  @override
  State<AudioMeter> createState() => _AudioMeterState();
}

class _AudioMeterState extends State<AudioMeter> {
  final double _level = 0.5; // Mock level for now
  String _selectedSource = 'Default Mic';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Mic', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: LinearProgressIndicator(
              value: _level,
              backgroundColor: Colors.grey.shade800,
              color: _level > 0.8 ? Colors.red : Colors.green,
              minHeight: 20,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButton<String>(
          value: _selectedSource,
          dropdownColor: Colors.grey.shade900,
          items: <String>['Default Mic', 'System Audio', 'External Mic'].map((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedSource = newValue;
              });
            }
          },
        ),
      ],
    );
  }
}
