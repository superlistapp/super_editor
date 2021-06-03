import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/document_interaction.dart';
import 'package:super_editor/src/default_editor/layout.dart';

import 'document_composer.dart';
import 'document_editor.dart';
import 'document_layout.dart';

/// Collection of core artifacts used to edit a document.
///
/// This contains the [editor], the [composer], as well as access to the
/// current [DocumentLayout] and the common editor operations.
///
/// Together, they are passed along to the [DocumentInteractor] or any other
/// user that needs to perform editing actions.
class EditContext {
  /// Creates an edit context that makes up a collection of core artifacts for
  /// editing a document.
  ///
  /// In particular, the context contains the editor, composer, and layout.
  /// While the [editor] and [composer] are passed directly, the
  /// [documentLayout] shall be provided via a [getDocumentLayout] callback that
  /// should return the current layout state.
  ///
  /// The [commonOps] are also passed to the edit context for direct access to
  /// common editor, composer, and layout operations.
  EditContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
    required this.composer,
    required this.commonOps,
  }) : _getDocumentLayout = getDocumentLayout;

  /// The editor of the [Document] that allows executing commands that alter the
  /// structure of the document.
  final DocumentEditor editor;

  /// The current document layout state.
  ///
  /// The member will always give access to the current state of the document
  /// layout, e.g. the state of the [DefaultDocumentLayout].
  DocumentLayout get documentLayout => _getDocumentLayout();
  final DocumentLayout Function() _getDocumentLayout;

  /// The composer of the document that maintains the [DocumentSelection].
  final DocumentComposer composer;

  /// The common operations that can be executed on the [editor], [composer],
  /// and [documentLayout] without directly calling them.
  final CommonEditorOperations commonOps;
}
