import 'package:super_editor/super_editor.dart';

extension Editables on Editor {
  MutableDocument get document => context.find<MutableDocument>(Editor.documentKey);

  MutableDocumentComposer get composer => context.find<MutableDocumentComposer>(Editor.composerKey);
}
