import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myway/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// A UI widget displaying lists of recently recorded video files.
///
/// Scans the resolved output storage directory, displaying details including
/// filenames, sizes, and modifications dates, and supporting playback, renaming,
/// and parent folder navigation.
class RecentRecordings extends StatefulWidget {
  /// Creates a new [RecentRecordings] view widget.
  const RecentRecordings({super.key});

  @override
  State<RecentRecordings> createState() => _RecentRecordingsState();
}

class _RecentRecordingsState extends State<RecentRecordings> {
  final _settings = SettingsService();
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scanFiles();
  }

  Future<void> _scanFiles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final folder = await _settings.getResolvedOutputFolder();
      final dir = Directory(folder);
      if (await dir.exists()) {
        final list = await dir.list().toList();
        final videoFiles = list.where((entity) {
          final path = entity.path.toLowerCase();
          return entity is File &&
              (path.endsWith('.mp4') || path.endsWith('.mkv'));
        }).toList();

        // Sort by modification time (newest first)
        videoFiles.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        });

        if (mounted) {
          setState(() {
            _files = videoFiles;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _files = [];
            _loading = false;
          });
        }
      }
    } catch (error) {
      debugPrint('Error scanning recordings: $error');
      if (mounted) {
        setState(() {
          _files = [];
          _loading = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _playVideo(String path) async {
    final uri = Uri.file(path);
    try {
      if (!await launchUrl(uri)) {
        throw 'Could not launch $uri';
      }
    } catch (error) {
      debugPrint('Error launching video: $error');
      // Fallback to xdg-open
      await Process.run('xdg-open', [path]);
    }
  }

  Future<void> _openFolder(String path) async {
    final file = File(path);
    final parentDir = file.parent.path;
    final uri = Uri.directory(parentDir);
    try {
      if (!await launchUrl(uri)) {
        throw 'Could not launch $uri';
      }
    } catch (error) {
      debugPrint('Error launching folder: $error');
      // Fallback to xdg-open
      await Process.run('xdg-open', [parentDir]);
    }
  }

  Future<void> _renameFile(File file) async {
    final currentName = file.path.split('/').last;
    final extension = currentName.substring(currentName.lastIndexOf('.'));
    final baseName = currentName.substring(0, currentName.lastIndexOf('.'));

    final controller = TextEditingController(text: baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Rename Recording'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'New Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text(
                'Rename',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.trim().isNotEmpty && newName != baseName) {
      final newPath = '${file.parent.path}/${newName.trim()}$extension';
      try {
        await file.rename(newPath);
        _scanFiles();
      } catch (error) {
        debugPrint('Error renaming file: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename file: $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_back_outlined,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              'No recordings found in output folder',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index] as File;
        final name = file.path.split('/').last;
        final stat = file.statSync();
        final sizeStr = _formatSize(stat.size);

        // Simple human-readable date
        final dateStr =
            '${stat.modified.year}-${stat.modified.month.toString().padLeft(2, '0')}-${stat.modified.day.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.grey.shade900.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade800),
          ),
          child: ListTile(
            leading: const Icon(Icons.video_file, color: Colors.teal),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$sizeStr • $dateStr',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _renameFile(file),
                ),
                IconButton(
                  tooltip: 'Play Recording',
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: () => _playVideo(file.path),
                ),
                IconButton(
                  tooltip: 'Open Directory',
                  icon: const Icon(Icons.folder_open, color: Colors.grey),
                  onPressed: () => _openFolder(file.path),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
