import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A UI screen displaying application ownership information, version telemetry,
/// developer website redirects, and GPL version 3 licensing details.
class AboutScreen extends StatefulWidget {
  /// Creates a new [AboutScreen] instance.
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: '0.0.0',
    buildNumber: '0',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      var info = await PackageInfo.fromPlatform();
      if (info.version.isEmpty ||
          info.version == '0.0.0' ||
          info.version == 'Unknown') {
        try {
          final jsonStr = await rootBundle.loadString('assets/version.json');
          final data = jsonDecode(jsonStr);
          info = PackageInfo(
            appName: data['app_name'] ?? info.appName,
            packageName: data['package_name'] ?? info.packageName,
            version: data['version'] ?? info.version,
            buildNumber: data['build_number'] ?? info.buildNumber,
            buildSignature: info.buildSignature,
          );
        } catch (assetErr) {
          debugPrint('Error reading fallback assets/version.json: $assetErr');
        }
      }
      if (mounted) {
        setState(() {
          _packageInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error fetching package info: $e');
    }
  }

  Future<void> _launchURL() async {
    final url = Uri.parse('https://nordheim.online');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'assets/myway.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'MyWay',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '✕',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  Column(
                    children: [
                      InkWell(
                        onTap: _launchURL,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/noln.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nordheim Online',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'MyWay Screen Recorder',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Version ${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Copyright Chuck Talk, a Nordheim Online Product',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Contact email for developer per CP-AboutPage with interactive mailto link
              InkWell(
                onTap: () async {
                  final emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'chuck@nordheim.online',
                  );
                  if (!await launchUrl(emailLaunchUri)) {
                    debugPrint('Could not launch $emailLaunchUri');
                  }
                },
                child: const Text(
                  'chuck@nordheim.online',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.teal,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'GNU Affero General Public License v3.0 (AGPL-3.0)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '''
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.''',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
