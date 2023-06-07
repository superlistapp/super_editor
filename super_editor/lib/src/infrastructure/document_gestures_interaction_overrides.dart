import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';

/// Delegate for mouse status and clicking on special types of content,
/// e.g., tapping on a link open the URL.
///
/// Listeners are notified when any time that the desired mouse cursor
/// may have changed.
abstract class ContentTapDelegate with ChangeNotifier {
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    return null;
  }

  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onDoubleTap(DocumentPosition tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onTripleTap(DocumentPosition tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }
}

enum TapHandlingInstruction {
  halt,
  continueHandling,
}
