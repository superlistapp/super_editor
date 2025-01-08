import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Delegate for mouse status and clicking on special types of content,
/// e.g., tapping on a link open the URL.
///
/// Each [ContentTapDelegate] notifies its listeners whenever an
/// internal policy changes, which might impact the mouse cursor
/// style. For example, a handler in a desktop app, when hovering
/// over a link, might initially show a text cursor, but when the
/// user pressed CMD (or CTL), the mouse cursor would change to a
/// click cursor. Only the individual handlers know when or if such
/// a change should occur. When such a change does occur, the
/// handler notifies its listeners, and the handler expects that
/// someone will ask it for the desired mouse cursor style.
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
