import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';

import 'document_composer.dart';
import 'document_editor.dart';
import 'document_layout.dart';

/// Collection of core artifacts used to edit a document.
///
/// In particular, the context contains the [DocumentEditor],
/// [DocumentComposer], and [DocumentLayout].
/// In addition, [commonOps] are available for directly applying common, complex
/// changes to the document using the artifacts.
class EditContext {
  /// Creates an edit context that makes up a collection of core artifacts for
  /// editing a document.
  ///
  /// The [documentLayout] is passed as a [getDocumentLayout] callback that
  /// should return the current layout as it might change.
  EditContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
    required this.composer,
    required this.commonOps,
  }) : _getDocumentLayout = getDocumentLayout;

  /// The editor of the [Document] that allows executing commands that alter the
  /// structure of the document.
  final DocumentEditor editor;

  /// The document layout that is a visual representation of the document.
  ///
  /// This member might change over time.
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;

  /// The [DocumentComposer] that maintains selection and attributions to work
  /// in conjunction with the [editor] to apply changes to the document.
  final DocumentComposer composer;

  /// Common operations that can be executed to apply common, complex changes to
  /// the document.
  final CommonEditorOperations commonOps;
}
