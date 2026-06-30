import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/capture_service.dart';

/// A UI widget displaying a real-time audio input level decibel meter and source selection.
class AudioMeter extends StatefulWidget {
  /// Callback triggered when the active audio device selection changes.
  final ValueChanged<AudioDevice?>? onDeviceChanged;

  /// Creates a new [AudioMeter] instance.
  const AudioMeter({super.key, this.onDeviceChanged});

  @override
  State<AudioMeter> createState() => _AudioMeterState();
}

class _AudioMeterState extends State<AudioMeter> {
  final _audioService = AudioService();
  final _captureService = CaptureService();

  List<AudioDevice> _devices = [];
  AudioDevice? _selectedDevice;
  double _level = 0.0;
  StreamSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _subscribeToMeter();
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = _audioService.getAvailableDevices();
      setState(() {
        _devices = list;
        if (list.isNotEmpty) {
          _selectedDevice = list.first;
          _startMonitoring(list.first.id);
          widget.onDeviceChanged?.call(list.first);
        } else {
          _selectedDevice = null;
          widget.onDeviceChanged?.call(null);
        }
        _loading = false;
      });
    } catch (error) {
      debugPrint('Error loading audio devices: $error');
      setState(() {
        _devices = [];
        _selectedDevice = null;
        _loading = false;
      });
      widget.onDeviceChanged?.call(null);
    }
  }

  void _subscribeToMeter() {
    _subscription = audioMonitorStreamController.stream.listen((levelValue) {
      if (mounted) {
        setState(() {
          _level = levelValue;
        });
      }
    });
  }

  void _startMonitoring(int nodeId) {
    try {
      _captureService.startAudioMonitor(nodeId);
    } catch (error) {
      debugPrint('Error starting audio monitor: $error');
    }
  }

  void _stopMonitoring() {
    try {
      _captureService.stopAudioMonitor();
    } catch (error) {
      debugPrint('Error stopping audio monitor: $error');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Mic Input Level',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: Container(
            width: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.5, 0.5, 0.75, 0.75, 1.0],
                        colors: [
                          Colors.green,
                          Colors.green,
                          Colors.yellow,
                          Colors.yellow,
                          Colors.red,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 1.0 - _level.clamp(0.0, 1.0),
                      child: Container(color: Colors.grey.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const SizedBox(
            height: 48,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.teal,
              ),
            ),
          )
        else if (_devices.isEmpty)
          const Text('No Mic Detected', style: TextStyle(color: Colors.red))
        else
          DropdownButton<AudioDevice>(
            value: _selectedDevice,
            dropdownColor: Colors.grey.shade900,
            isExpanded: true,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
            selectedItemBuilder: (context) {
              return _devices.map((device) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.teal),
                  ),
                );
              }).toList();
            },
            items: _devices.map((device) {
              return DropdownMenuItem<AudioDevice>(
                value: device,
                child: Text(device.name, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (newDevice) {
              if (newDevice != null && newDevice != _selectedDevice) {
                _stopMonitoring();
                setState(() {
                  _selectedDevice = newDevice;
                  _level = 0.0;
                });
                _startMonitoring(newDevice.id);
                widget.onDeviceChanged?.call(newDevice);
              }
            },
          ),
      ],
    );
  }
}
