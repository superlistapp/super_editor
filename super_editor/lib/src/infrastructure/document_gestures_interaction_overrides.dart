import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Delegate for mouse status and clicking on special types of content,
/// e.g., tapping on a link open the URL.
///
/// Listeners are notified when any time that the desired mouse cursor
/// may have changed.
abstract class ContentTapDelegate with ChangeNotifier {
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    return null;
  }

  TapHandlingInstruction onTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onTripleTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }
}

/// Information about a gesture that occured within a [DocumentLayout].
class DocumentTapDetails {
  DocumentTapDetails({
    required this.documentLayout,
    required this.layoutOffset,
    required this.globalOffset,
  });

  /// The document layout.
  ///
  /// It can be used to pull information about the logical position
  /// where the tap occurred. For example, to find the [DocumentPosition]
  /// that is nearest to the tap, to find if the tap ocurred above
  /// the first node or below the last node, etc.
  final DocumentLayout documentLayout;

  /// The position of the gesture in [DocumentLayout]'s coordinate space.
  final Offset layoutOffset;

  /// The position of the gesture in global coordinates.
  final Offset globalOffset;
}

enum TapHandlingInstruction {
  halt,
  continueHandling,
}
