import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';

/// Collection of core artifacts used to display a read-only document.
///
/// In particular, the context contains the [Document], [DocumentSelection],
/// and [DocumentLayout].
class SuperReaderContext {
  /// Creates document context that makes up a collection of core artifacts for
  /// displaying a read-only document.
  ///
  /// The [documentLayout] is passed as a [getDocumentLayout] callback that
  /// should return the current layout as it might change.
  SuperReaderContext({
    required this.document,
    required DocumentLayout Function() getDocumentLayout,
    required this.selection,
    required this.scroller,
  }) : _getDocumentLayout = getDocumentLayout;

  /// The [Document] that's currently being displayed.
  final Document document;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;

  /// The current selection within the displayed document.
  final ValueNotifier<DocumentSelection?> selection;

  /// The [DocumentScroller] that provides status and control over [SuperReader]
  /// scrolling.
  final DocumentScroller scroller;
}
