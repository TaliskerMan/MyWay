class RecordingParams {
  final String mode; // "fullscreen", "window", "area"
  final String codec; // "h265", "h264", "av1"
  final int videoBitrate;
  final int videoNodeId; // Wayland PipeWire video stream node ID
  final int waylandFd;
  final int audioNodeId;
  final String outputPath;
  final int areaX;
  final int areaY;
  final int areaWidth;
  final int areaHeight;
  final bool
  isWayland; // true for Wayland (PipeWire), false for X11 (ximagesrc)

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
}
