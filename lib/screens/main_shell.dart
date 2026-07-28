import 'package:flutter/material.dart';
import 'package:myway/screens/about_screen.dart';
import 'package:myway/screens/audio_setup_screen.dart';
import 'package:myway/screens/library_screen.dart';
import 'package:myway/screens/recording_screen.dart';
import 'package:myway/screens/settings_screen.dart';
import 'package:myway/screens/support_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main scaffolding layout shell hosting the navigation rail and page view switches.
class MainShell extends StatefulWidget {
  /// Creates a new [MainShell] layout container.
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  Future<void> _launchURL() async {
    final url = Uri.parse('https://nordheim.online');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = const AudioSetupScreen();
      case 1:
        page = const SettingsScreen();
      case 2:
        page = const RecordingScreen();
      case 3:
        page = const LibraryScreen();
      case 4:
        page = const SupportScreen();
      case 5:
        page = const AboutScreen();
      default:
        throw UnimplementedError('no widget for $_selectedIndex');
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.mic_none),
                selectedIcon: Icon(Icons.mic),
                label: Text('Audio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam),
                label: Text('Record'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.support_agent_outlined),
                selectedIcon: Icon(Icons.support_agent),
                label: Text('Support'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: Text('About'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: _launchURL,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/noln.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
