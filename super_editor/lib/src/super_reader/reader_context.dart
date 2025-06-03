import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';

/// Collection of core artifacts used to display a read-only document.
///
/// While [SuperReaderContext] includes an [editor], it's expected that clients
/// of a [SuperReaderContext] do not allow users to alter [Document] within
/// the [editor]. Instead, the [editor] provides access to a [Document], a
/// [DocumentComposer] to display and alter selections, and the ability for
/// code to alter the [Document], such as an AI GPT system.
class SuperReaderContext {
  SuperReaderContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
    required this.scroller,
  }) : _getDocumentLayout = getDocumentLayout;

  final Editor editor;

  /// The [Document] that's currently being displayed.
  Document get document => editor.document;

  /// The current selection within the displayed document.
  DocumentComposer get composer => editor.composer;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;

  /// The [DocumentScroller] that provides status and control over [SuperReader]
  /// scrolling.
  final DocumentScroller scroller;
}
