import 'package:flutter/foundation.dart';

import 'document.dart';

class DocumentEditor {
  DocumentEditor({
    @required RichTextDocument document,
  }) : _document = document;

  final RichTextDocument _document;

  void executeCommand(EditorCommand command) {
    command.execute(_document);
  }
}

abstract class EditorCommand {
  void execute(RichTextDocument document);
}
