import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/super_textfield/ios/ios_textfield.dart';

void main() {
  group('SuperTextField iOS', () {
    group('system context menu anchor', () {
      test('builds a rect from finite anchors', () {
        final rect = sanitizeSystemContextMenuAnchor(
          const Offset(10, 20),
          const Offset(10, 40),
        );

        expect(rect, const Rect.fromLTRB(10, 20, 10, 40));
      });

      test('returns null when an anchor is null', () {
        expect(sanitizeSystemContextMenuAnchor(null, const Offset(10, 40)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(10, 20), null), isNull);
        expect(sanitizeSystemContextMenuAnchor(null, null), isNull);
      });

      // Regression test for SUPERLIST-FRONTEND-2BBX: a singular ancestor render
      // transform during an overlay/keyboard transition can make the anchor
      // offsets NaN/Infinity. Such a rect must not reach the platform channel,
      // where NaN throws JsonUnsupportedObjectError when JSON-encoded.
      test('returns null when an anchor component is not finite', () {
        const nan = double.nan;
        const inf = double.infinity;

        expect(sanitizeSystemContextMenuAnchor(const Offset(nan, 20), const Offset(10, 40)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(10, nan), const Offset(10, 40)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(10, 20), const Offset(nan, 40)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(10, 20), const Offset(10, nan)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(inf, 20), const Offset(10, 40)), isNull);
        expect(sanitizeSystemContextMenuAnchor(const Offset(10, -inf), const Offset(10, 40)), isNull);
      });
    });
  });
}
