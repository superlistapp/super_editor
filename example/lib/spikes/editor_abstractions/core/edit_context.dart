import 'package:flutter/foundation.dart';

import 'document.dart';
import 'document_composer.dart';
import 'document_editor.dart';
import 'document_layout.dart';

/// Collection of core artifacts used to edit a document.
class EditContext {
  EditContext({
    @required this.document,
    @required this.editor,
    @required this.documentLayout,
    @required this.composer,
  });

  final Document document;
  final DocumentEditor editor;
  final DocumentLayout documentLayout;
  final DocumentComposer composer;
}
