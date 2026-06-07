import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  
  Logger? _logger;
  File? _logFile;
  bool _isEnabled = false;

  LogService._internal();

  Future<void> init(bool isEnabled) async {
    _isEnabled = isEnabled;
    if (_isEnabled) {
      final directory = await getApplicationSupportDirectory();
      _logFile = File('${directory.path}/myway_debug.log');
      
      _logger = Logger(
        printer: PrettyPrinter(methodCount: 0, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart),
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

  void logInfo(String message) {
    if (_isEnabled && _logger != null) {
      _logger!.i(message);
    }
  }

  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isEnabled && _logger != null) {
      _logger!.e(message, error: error, stackTrace: stackTrace);
    }
  }

  Future<String?> exportLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return null;
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) return null;

      final outputPath = '${downloadsDir.path}/MyWay_Logs.tar.gz';
      
      // Read the log file
      final fileBytes = await _logFile!.readAsBytes();
      
      // Create an Archive with the file
      final archive = Archive();
      final archiveFile = ArchiveFile('myway_debug.log', fileBytes.length, fileBytes);
      archive.addFile(archiveFile);
      
      // Encode it to tar
      final tarData = TarEncoder().encode(archive);
      
      // Encode it to gzip
      final gzipData = GZipEncoder().encode(tarData);
      
      // Write the compressed data to the output file
      final outFile = File(outputPath);
      await outFile.writeAsBytes(gzipData);
      
      return outputPath;
    } catch (e) {
      logError("Failed to export logs", e);
      return null;
    }
  }
}
