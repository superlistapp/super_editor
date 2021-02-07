import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// TODO: get rid of these imports
import '../../default_editor/text.dart';
import '../../default_editor/box_component.dart';
import '../../selectable_text/attributed_text.dart';
import '../../default_editor/paragraph.dart';
import '../selection/editor_selection.dart';
import 'rich_text_document.dart';

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
