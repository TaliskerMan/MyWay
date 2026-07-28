// Tests for the native-buffer string encoder (P0-2 fix). These call the static
// helper directly, so the CaptureService constructor (which dlopen()s the
// native library) is never invoked — the tests run anywhere.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:myway/services/capture_service.dart';

void main() {
  group('CaptureService.encodeForNativeBuffer', () {
    test('encodes ASCII as UTF-8 bytes', () {
      final out = CaptureService.encodeForNativeBuffer(
        '/home/u/Videos/a.mp4',
        1024,
      );
      expect(out, utf8.encode('/home/u/Videos/a.mp4'));
    });

    test('encodes non-ASCII paths as UTF-8, not UTF-16 code units', () {
      const path = '/home/u/Vidéos/café_😀.mp4'; // accents + CJK-ish + emoji
      final out = CaptureService.encodeForNativeBuffer(path, 1024);
      expect(out, utf8.encode(path));
      // Round-trips back to the original string.
      expect(utf8.decode(out), path);
      // Regression guard: UTF-16 code units would differ for multi-byte chars.
      expect(out, isNot(equals(path.codeUnits)));
    });

    test('leaves room for the NUL terminator (max maxLength-1 bytes)', () {
      final long = 'a' * 5000;
      final out = CaptureService.encodeForNativeBuffer(long, 1024);
      expect(out.length, lessThanOrEqualTo(1023));
    });

    test('does not split a multi-byte UTF-8 sequence at the boundary', () {
      // 'é' is 2 bytes in UTF-8. Fill so the truncation lands mid-character.
      final s = '${'a' * 8}${'é' * 4}'; // 8 + 8 bytes = 16 bytes
      final out = CaptureService.encodeForNativeBuffer(s, 11); // cap 10 bytes
      // Whatever is kept must still be valid UTF-8 (no half characters).
      expect(() => utf8.decode(out), returnsNormally);
      expect(out.length, lessThanOrEqualTo(10));
    });
  });
}
