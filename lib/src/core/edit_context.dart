import 'document_composer.dart';
import 'document_editor.dart';
import 'document_layout.dart';

/// Collection of core artifacts used to edit a document.
class EditContext {
  EditContext({
    required this.editor,
    required DocumentLayout Function() getDocumentLayout,
    required this.composer,
  }) : _getDocumentLayout = getDocumentLayout;

  final DocumentEditor editor;

  DocumentLayout Function() _getDocumentLayout;
  DocumentLayout get documentLayout => _getDocumentLayout();

  final DocumentComposer composer;
}
