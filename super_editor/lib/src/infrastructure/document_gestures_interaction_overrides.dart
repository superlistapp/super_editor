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

  TapHandlingInstruction onTap(DocumentTapDetails tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onDoubleTap(DocumentTapDetails tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onTripleTap(DocumentTapDetails tapPosition) {
    return TapHandlingInstruction.continueHandling;
  }
}

/// Information about a gesture that occured near a [position].
class DocumentTapDetails {
  DocumentTapDetails({
    required this.position,
    required this.isGestureAboveStartOfDocument,
    required this.isGestureBelowEndOfDocument,
  });

  /// The position in the document where the gesture occurred.
  ///
  /// When there is no content at the gesture location, this position
  /// holds the nearest position in the document.
  final DocumentPosition position;

  /// Whether the gesture occurred above the first node in the document.
  final bool isGestureAboveStartOfDocument;

  /// Whether the gesture occurred below the last node in the document.
  final bool isGestureBelowEndOfDocument;
}

enum TapHandlingInstruction {
  halt,
  continueHandling,
}
