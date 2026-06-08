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

class MyWayApp extends StatelessWidget {
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
