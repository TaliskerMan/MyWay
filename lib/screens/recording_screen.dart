import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recording_params.dart';
import '../services/capture_service.dart';
import '../services/portal_service.dart';
import '../services/settings_service.dart';

/// Main interactive control screen managing recording state triggers,
/// capture types selection, and PipeWire/GStreamer lifecycle setups.
class RecordingScreen extends StatefulWidget {
  /// Creates a new [RecordingScreen] control instance.
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final _captureService = CaptureService();
  final _settings = SettingsService();

  String _captureMode = 'fullscreen';
  bool _isRecording = false;
  bool _isPromptingPortal = false;
  PortalService? _portal;
  int _durationSec = 0;
  Rect? _selectedArea;
  StreamSubscription? _statusSubscription;
  String? _currentRecordingPath;

  int? _selectedWindowId;
  String? _selectedWindowTitle;

  bool get _isWayland =>
      Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() == 'wayland' ||
      Platform.environment['WAYLAND_DISPLAY'] != null;

  @override
  void initState() {
    super.initState();
    _captureService.initialize();
    _subscribeToStatus();
  }

  void _subscribeToStatus() {
    _statusSubscription = captureStatusStreamController.stream.listen((status) {
      if (mounted) {
        setState(() {
          _durationSec = status.durationSec;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _portal?.close();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _startRecording() async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_isWayland && _captureMode == 'window' && _selectedWindowId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a window to record first.'),
        ),
      );
      return;
    }

    setState(() {
      if (_isWayland) {
        _isPromptingPortal = true;
      }
      _durationSec = 0;
    });

    try {
      int videoNodeId = 0;
      int waylandFd = 0;
      if (_isWayland) {
        // 1. Get PipeWire stream Node ID and FD via Wayland portal
        _portal = PortalService();
        final result = await _portal!.obtainVideoNodeId();
        videoNodeId = result.nodeId;
        waylandFd = result.fd;
      } else {
        if (_captureMode == 'window') {
          videoNodeId = _selectedWindowId ?? 0;
        }
      }

      // 2. Load configurations from settings
      final audioDeviceId = await _settings.getAudioDeviceId();
      final codec = await _settings.getCodec();
      final bitrate = await _settings.getBitrate();
      final resolvedFolder = await _settings.getResolvedOutputFolder();

      // Ensure output directory exists
      final outDir = Directory(resolvedFolder);
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final fileName = 'myway_rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputFilePath = '${outDir.path}/$fileName';
      _currentRecordingPath = outputFilePath;

      // 3. Assemble parameters
      final params = RecordingParams(
        mode: _captureMode,
        codec: codec,
        videoBitrate: bitrate,
        videoNodeId: videoNodeId,
        waylandFd: waylandFd,
        audioNodeId: audioDeviceId,
        outputPath: outputFilePath,
        isWayland: _isWayland,
        areaX: _selectedArea?.left.toInt() ?? 0,
        areaY: _selectedArea?.top.toInt() ?? 0,
        areaWidth: _selectedArea?.width.toInt() ?? 0,
        areaHeight: _selectedArea?.height.toInt() ?? 0,
      );

      // 5. Start GStreamer capturing in C
      _captureService.startCapture(params);

      setState(() {
        _isRecording = true;
        _isPromptingPortal = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Recording started successfully.')),
      );
    } catch (e) {
      debugPrint('Error starting capture: $e');
      setState(() {
        _isPromptingPortal = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
    // We do NOT close the portal here, because the DBus connection must remain open
    // for the duration of the recording. We will close it in _stopRecording.
  }

  Future<void> _stopRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      _captureService.stopCapture();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Recording saved: ${_currentRecordingPath?.split('/').last}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error stopping capture: $e');
    }

    setState(() {
      _isRecording = false;
      _currentRecordingPath = null;
    });
  }

  Future<void> _launchWindowSelector() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Click on the window you want to record.'),
        duration: Duration(seconds: 3),
      ),
    );
    try {
      final result = await Process.run('xwininfo', ['-int']);
      if (result.exitCode == 0) {
        final stdout = result.stdout.toString();
        // Parse format: "xwininfo: Window id: 1234567 "Window Title""
        final idMatch = RegExp(r'Window id:\s*(\d+)').firstMatch(stdout);
        if (idMatch != null) {
          final idStr = idMatch.group(1)!;
          final id = int.tryParse(idStr);

          // Try to parse the window title which is wrapped in double quotes
          String? title;
          final titleMatch = RegExp(
            r'Window id:\s*\d+\s+"([^"]*)"',
          ).firstMatch(stdout);
          if (titleMatch != null) {
            title = titleMatch.group(1);
          } else {
            final nameMatch = RegExp(
              r'xwininfo:\s*Window id:\s*\d+\s+(.*)',
            ).firstMatch(stdout);
            if (nameMatch != null) {
              title = nameMatch.group(1)?.trim();
            }
          }

          setState(() {
            _selectedWindowId = id;
            _selectedWindowTitle = title ?? 'Unnamed Window';
          });
        }
      }
    } catch (e) {
      debugPrint('Error selecting window: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to select window: $e')),
      );
    }
  }

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
                Row(
                  children: [
                    const Text(
                      'MyWay',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/myway.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                const Text(
                  'Select Recording Type',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildModeButton(
                      'Full Screen',
                      'fullscreen',
                      Icons.monitor,
                    ),
                    const SizedBox(width: 16),
                    _buildModeButton('Window', 'window', Icons.window),
                  ],
                ),
                const SizedBox(height: 24),
                if (_captureMode == 'window' && !_isWayland) ...[
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isRecording || _isPromptingPortal
                            ? null
                            : _launchWindowSelector,
                        icon: const Icon(Icons.ads_click),
                        label: Text(
                          _selectedWindowId == null
                              ? 'Select Window to Record'
                              : 'Change Window',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_selectedWindowId != null)
                        Expanded(
                          child: Text(
                            'Selected: "${_selectedWindowTitle ?? 'Unknown'}" (ID: $_selectedWindowId)',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Text(
                          'No window selected.',
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                const Spacer(),
                if (_isPromptingPortal)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.teal),
                        SizedBox(height: 16),
                        Text(
                          'Waiting for Wayland Screen Share Permission...',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isRecording)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const BlinkingRedDot(),
                            const SizedBox(width: 12),
                            Text(
                              _formatDuration(_durationSec),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Recording is Active',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRecording || _isPromptingPortal
                          ? null
                          : _startRecording,
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
                        disabledBackgroundColor: Colors.red.withValues(
                          alpha: 0.4,
                        ),
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
                      onPressed: !_isRecording ? null : _stopRecording,
                      icon: const Icon(Icons.stop, color: Colors.white),
                      label: const Text(
                        'Stop',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.blue.withValues(
                          alpha: 0.4,
                        ),
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
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, String value, IconData icon) {
    final isSelected = _captureMode == value;
    final isDisabled = _isRecording || _isPromptingPortal;
    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _captureMode = value;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
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
      ),
    );
  }
}

/// A simple status indicator widget that fades in and out to signify
/// that video/audio recording is actively running.
class BlinkingRedDot extends StatefulWidget {
  /// Creates a [BlinkingRedDot] animation widget.
  const BlinkingRedDot({super.key});

  @override
  State<BlinkingRedDot> createState() => _BlinkingRedDotState();
}

class _BlinkingRedDotState extends State<BlinkingRedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
