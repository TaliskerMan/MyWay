import 'package:flutter/material.dart';
import 'package:myway/widgets/recent_recordings.dart';

/// A UI screen hosting the recordings library and listing past captures.
class LibraryScreen extends StatelessWidget {
  /// Creates a new [LibraryScreen] instance.
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recordings Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.video_library, color: Colors.teal, size: 32),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'View, play, or rename your captured recordings.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 24),
          Expanded(
            child: RecentRecordings(),
          ),
        ],
      ),
    );
  }
}
