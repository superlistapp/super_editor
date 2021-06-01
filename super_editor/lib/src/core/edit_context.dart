import 'package:super_editor/src/default_editor/common_editor_operations.dart';

import 'document_composer.dart';
import 'document_editor.dart';
import 'document_layout.dart';

/// Collection of core artifacts used to edit a document.
class EditContext {
  EditContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
    required this.composer,
    required this.commonOps,
  }) : _getDocumentLayout = getDocumentLayout;

  final DocumentEditor editor;

  final DocumentLayout Function() _getDocumentLayout;
  DocumentLayout get documentLayout => _getDocumentLayout();

  final DocumentComposer composer;

  final CommonEditorOperations commonOps;
}
