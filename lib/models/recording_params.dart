class RecordingParams {
  final String mode; // "fullscreen", "window", "area"
  final String codec; // "h265", "h264", "av1"
  final int videoBitrate;
  final int audioNodeId;
  final String outputPath;
  final int areaX;
  final int areaY;
  final int areaWidth;
  final int areaHeight;

  RecordingParams({
    required this.mode,
    required this.codec,
    required this.videoBitrate,
    required this.audioNodeId,
    required this.outputPath,
    this.areaX = 0,
    this.areaY = 0,
    this.areaWidth = 0,
    this.areaHeight = 0,
  });
}
