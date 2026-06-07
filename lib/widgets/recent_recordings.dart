import 'package:flutter/material.dart';

class RecentRecordings extends StatelessWidget {
  const RecentRecordings({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3, // Mock data
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.video_file),
          title: Text('myway_recording_$index.mkv'),
          subtitle: const Text('1920x1080 • 12 MB • H.265 HW'),
          trailing: IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {},
          ),
        );
      },
    );
  }
}
