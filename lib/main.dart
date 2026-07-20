// Auto-incremented to version 1.0.2 for build release on 2026-07-20 (Rule_017)
// Auto-incremented to version 1.0.1 for build release on 2026-06-08 (Rule_017)
import 'package:flutter/material.dart';
import 'screens/main_shell.dart';

import 'services/log_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();
  final isLoggingEnabled = await settings.getLoggingEnabled();
  await LogService().init(isLoggingEnabled);
  LogService().logInfo("MyWay Application Started");

  runApp(const MyWayApp());
}

/// The main application widget for the MyWay screen recorder client.
class MyWayApp extends StatelessWidget {
  /// Creates a new [MyWayApp] instance.
  const MyWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyWay Screen Recorder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
