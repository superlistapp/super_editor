import 'package:mockito/mockito.dart';
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
}) {
  return EditContext(
    editor: documentEditor ?? DocumentEditor(document: document),
    getDocumentLayout: () => documentLayout ?? FakeDocumentLayout(),
    composer: documentComposer ?? DocumentComposer(),
  );
}
