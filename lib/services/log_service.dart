import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

/// Singleton service providing unified console and file logging.
///
/// Manages file buffers, log level classification, and gzip archive exports.
class LogService {
  static final LogService _instance = LogService._internal();

  /// Retrieve the singleton instance of [LogService].
  factory LogService() => _instance;

  Logger? _logger;
  File? _logFile;
  bool _isEnabled = false;

  LogService._internal();

  /// Initializes the logger instance and configuration.
  ///
  /// Binds log outputs to console and local file paths if [isEnabled] is true.
  Future<void> init(bool isEnabled) async {
    _isEnabled = isEnabled;
    if (_isEnabled) {
      final directory = await getApplicationSupportDirectory();
      _logFile = File('${directory.path}/myway_debug.log');

      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          if (_logFile != null) FileOutput(file: _logFile!),
        ]),
      );
      _logger?.i("Logging enabled.");
    } else {
      _logger?.i("Logging disabled.");
      _logger = null;
    }
  }

  /// Logs an informational [message] to the active outputs.
  void logInfo(String message) {
    if (_isEnabled && _logger != null) {
      _logger!.i(message);
    }
  }

  /// Logs an error message with optional [error] objects and [stackTrace] maps.
  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isEnabled && _logger != null) {
      _logger!.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Compresses the active log file to a `.tar.gz` archive in the User Downloads folder.
  ///
  /// Returns the absolute path to the generated archive, or null on failure.
  Future<String?> exportLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return null;
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) return null;

      final outputPath = '${downloadsDir.path}/MyWay_Logs.tar.gz';

      // Flush logger buffers by closing it
      if (_logger != null) {
        await _logger!.close();
      }

      // Read the log file
      final fileBytes = await _logFile!.readAsBytes();

      // Reinitialize logger to continue logging
      if (_isEnabled) {
        _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
          output: MultiOutput([
            ConsoleOutput(),
            if (_logFile != null) FileOutput(file: _logFile!),
          ]),
        );
      }

      // Create an Archive with the file
      final archive = Archive();
      final archiveFile = ArchiveFile(
        'myway_debug.log',
        fileBytes.length,
        fileBytes,
      );
      archive.addFile(archiveFile);

      // Encode it to tar
      final tarData = TarEncoder().encode(archive);

      // Encode it to gzip
      final gzipData = GZipEncoder().encode(tarData);

      // Write the compressed data to the output file
      final outFile = File(outputPath);
      await outFile.writeAsBytes(gzipData);

      return outputPath;
    } catch (error) {
      logError("Failed to export logs", error);
      return null;
    }
  }

  /// Reads and returns the last [count] lines of the log file.
  Future<String> getLastLogLines(int count) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return "Log file not found or logging disabled.";
    }
    try {
      final lines = await _logFile!.readAsLines();
      if (lines.isEmpty) return "Log file is empty.";
      
      final startIndex = (lines.length > count) ? lines.length - count : 0;
      final recentLines = lines.sublist(startIndex);
      return recentLines.join('\n');
    } catch (error) {
      return "Error reading log file: $error";
    }
  }
}
