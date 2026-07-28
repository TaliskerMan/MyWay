import 'package:flutter/material.dart';
import 'package:myway/services/log_service.dart';
import 'package:myway/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// UI support and diagnostics screen offering debug log toggle options,
/// email reporting utilities, and recent log outputs console rendering.
class SupportScreen extends StatefulWidget {
  /// Creates a new [SupportScreen] instance.
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final SettingsService _settings = SettingsService();
  bool _isLoggingEnabled = false;
  String _logContent = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshLogs();
  }

  Future<void> _refreshLogs() async {
    final logs = await LogService().getLastLogLines(100);
    if (mounted) {
      setState(() {
        _logContent = logs;
      });
    }
  }

  Future<void> _loadSettings() async {
    _isLoggingEnabled = await _settings.getLoggingEnabled();
    setState(() {});
  }

  Future<void> _toggleLogging(bool value) async {
    setState(() {
      _isLoggingEnabled = value;
    });
    await _settings.setLoggingEnabled(value);
    await LogService().init(value);

    if (value) {
      LogService().logInfo(
        'User manually enabled debug logging from Support UI.',
      );
    }
    _refreshLogs();
  }

  Future<void> _exportAndEmailLogs() async {
    if (!_isLoggingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Logging is not enabled. Please enable it first to gather logs.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final archivePath = await LogService().exportLogs();

    if (archivePath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logs archived successfully to:\\n$archivePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      final mailUrl = Uri(
        scheme: 'mailto',
        path: 'support@nordheim.online',
        queryParameters: {
          'subject': 'MyWay error logs for Support request',
          'body':
              r'Please describe your issue here.\n\n'
              '[IMPORTANT: Do not forget to attach the MyWay_Logs.tar.gz file located at: $archivePath]',
        },
      );

      if (!await launchUrl(mailUrl)) {
        debugPrint('Could not launch mail client');
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to export logs. Ensure the log file exists and you have write permissions.',
          ),
          backgroundColor: Colors.red,
        ),
      );
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
            'Support & Diagnostics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text('Enable Debug Logging'),
                      subtitle: const Text(
                        'Saves diagnostic logs locally to your machine. '
                        'We never automatically upload telemetry. By design, you must manually export and send these logs if you require support.',
                      ),
                      value: _isLoggingEnabled,
                      onChanged: _toggleLogging,
                      activeTrackColor: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _exportAndEmailLogs,
                      icon: const Icon(Icons.mark_email_read),
                      label: const Text('Export Logs & Contact Support'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Logs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.teal),
                        onPressed: _refreshLogs,
                        tooltip: 'Refresh Logs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _logContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
