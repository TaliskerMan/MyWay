import 'package:flutter/material.dart';
import '../widgets/recent_recordings.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
                'Recordings Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.video_library, color: Colors.teal, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'View, play, or rename your captured recordings.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: RecentRecordings(),
          ),
        ],
      ),
    );
  }
}
