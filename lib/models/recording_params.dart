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
    this.maxHeight = 0,
  });

  /// The capture mode: "fullscreen" or "window".
  final String mode;

  /// The video encoding codec: "h265", "h264", or "av1".
  final String codec;

  /// Target video encoding bitrate in kbps.
  final int videoBitrate;

  /// The PipeWire stream node ID for Wayland video capture.
  final int videoNodeId;

  /// Native Wayland connection file descriptor.
  final int waylandFd;

  /// Audio capture input device/node ID.
  final int audioNodeId;

  /// The absolute output destination path for the recorded media file.
  final String outputPath;

  /// Whether the session runs on a Wayland display server (requires PipeWire)
  /// rather than X11 (uses ximagesrc).
  final bool isWayland;

  /// Largest output height in pixels; 0 records at the source resolution.
  /// The video is only ever scaled down, never up.
  final int maxHeight;
}
