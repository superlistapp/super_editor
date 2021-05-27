import 'package:mockito/mockito.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/super_editor.dart';

/// Fake [DocumentLayout], intended for tests that interact with
/// a logical [DocumentLayout] but do not depend upon a real
/// widget tree with a real [DocumentLayout] implementation.
class FakeDocumentLayout with Mock implements DocumentLayout {}

EditContext createEditContext({
  required MutableDocument document,
  DocumentEditor? documentEditor,
  DocumentLayout? documentLayout,
  DocumentComposer? documentComposer,
  CommonEditorOperations? commonOps,
}) {
  final editor = documentEditor ?? DocumentEditor(document: document);
  final layoutResolver = () => documentLayout ?? FakeDocumentLayout();
  final composer = documentComposer ?? DocumentComposer();

  return EditContext(
    editor: editor,
    getDocumentLayout: layoutResolver,
    composer: composer,
    commonOps: commonOps ??
        CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: layoutResolver,
        ),
  );
}
