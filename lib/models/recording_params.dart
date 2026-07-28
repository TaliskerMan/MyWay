/// Configuration parameters required to initialize a screen and audio capture session.
class RecordingParams {
  /// Creates a [RecordingParams] configuration instance.
  RecordingParams({
    required this.mode,
    required this.codec,
    required this.videoBitrate,
    required this.videoNodeId,
    required this.audioNodeId,
    required this.outputPath,
    required this.isWayland,
    this.waylandFd = 0,
    this.areaX = 0,
    this.areaY = 0,
    this.areaWidth = 0,
    this.areaHeight = 0,
  });

  /// The capture mode: "fullscreen", "window", or "area".
  final String mode;

  /// The video encoding codec: "h265", "h264", or "av1".
  final String codec;

  /// Target video encoding bitrate in bps.
  final int videoBitrate;

  /// The PipeWire stream node ID for Wayland video capture.
  final int videoNodeId;

  /// Native Wayland connection file descriptor.
  final int waylandFd;

  /// Audio capture input device/node ID.
  final int audioNodeId;

  /// The absolute output destination path for the recorded media file.
  final String outputPath;

  /// Horizontal coordinate offset of the custom capture area bounding box.
  final int areaX;

  /// Vertical coordinate offset of the custom capture area bounding box.
  final int areaY;

  /// Width dimension of the custom capture area bounding box.
  final int areaWidth;

  /// Height dimension of the custom capture area bounding box.
  final int areaHeight;

  /// Whether the session runs on a Wayland display server (requires PipeWire)
  /// rather than X11 (uses ximagesrc).
  final bool isWayland;
}
