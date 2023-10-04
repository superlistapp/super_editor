import 'package:flutter/painting.dart';

extension Bounds on TextSelection {
  /// Returns `true` if this [TextSelection] has the same bounds as the
  /// [other] [TextSelection], regardless of selection direction, i.e.,
  /// affinity.
  bool hasSameBoundsAs(TextSelection other) {
    return start == other.start && end == other.end;
  }
}
