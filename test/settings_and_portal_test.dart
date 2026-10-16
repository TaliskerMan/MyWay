import 'package:flutter_test/flutter_test.dart';
import 'package:myway/services/portal_service.dart';
import 'package:myway/services/settings_service.dart';

void main() {
  group('Recording quality', () {
    test('maps every choice to a maximum height (source = no scaling)', () {
      expect(SettingsService.qualityMaxHeights, {
        'source': 0,
        '720p': 720,
        '1080p': 1080,
        '2160p': 2160,
      });
    });
  });

  group('SettingsService.resolveFolder', () {
    test('expands ~/ using HOME', () {
      expect(
        SettingsService.resolveFolder('~/Videos', '/home/alice'),
        '/home/alice/Videos',
      );
    });

    test('expands a bare ~', () {
      expect(SettingsService.resolveFolder('~', '/home/alice'), '/home/alice');
    });

    test('leaves absolute paths alone', () {
      expect(
        SettingsService.resolveFolder('/mnt/media/rec', '/home/alice'),
        '/mnt/media/rec',
      );
    });

    test('never falls back to a hard-coded user directory', () {
      final resolved = SettingsService.resolveFolder('~/Videos', null);
      expect(resolved.contains('freecode'), isFalse);
      expect(resolved.endsWith('/Videos'), isTrue);
    });
  });

  group('PortalService.folderPathFromUri', () {
    test('decodes file URIs, including spaces and non-ASCII', () {
      expect(
        PortalService.folderPathFromUri('file:///home/alice/My%20Videos'),
        '/home/alice/My Videos',
      );
      expect(
        PortalService.folderPathFromUri('file:///home/alice/Vid%C3%A9os'),
        '/home/alice/Vidéos',
      );
    });

    test('rejects non-file URIs', () {
      expect(PortalService.folderPathFromUri('https://example.com/x'), isNull);
    });
  });
}
