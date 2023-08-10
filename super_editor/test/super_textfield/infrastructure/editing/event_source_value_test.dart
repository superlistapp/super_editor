import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

void main() {
  group("EventSourcedAttributedTextEditingValue", () {
    group("undo/redo", () {
      test("can execute commands", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "a")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "b")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "c")));

        expect(editingValue.text.text, "abc");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 3));
      });

      test("can undo commands", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "a")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "b")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "c")));

        // Undo the insertions.
        editingValue.undo();
        expect(editingValue.text.text, "ab");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 2));

        editingValue.undo();
        expect(editingValue.text.text, "a");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 1));

        editingValue.undo();
        expect(editingValue.text.text, "");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 0));
      });

      test("does nothing when undoing an empty history", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        editingValue.undo();

        expect(editingValue.text.text, "");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 0));
      });

      test("can redo commands", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        // Run a series of insertions, undo's, and redo's to ensure that
        // we can redo operations at various times.
        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "a")))
          ..undo()
          ..redo();
        expect(editingValue.text.text, "a");

        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "b")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "c")))
          ..undo()
          ..undo()
          ..redo();
        expect(editingValue.text.text, "ab");
        editingValue.redo();
        expect(editingValue.text.text, "abc");
      });

      test("does nothing when redoing an empty future", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        editingValue.redo();

        expect(editingValue.text.text, "");
        expect(editingValue.selection, const TextSelection.collapsed(offset: 0));
      });

      test("cannot redo after running a new command", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        // Run a series of insertions, undo's, and redo's to ensure that
        // we can redo operations at various times.
        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "a")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "b")))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "c")))
          ..undo()
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "d")));

        expect(editingValue.text.text, "abd");
        expect(editingValue.isRedoable, isFalse);
      });

      test("runs batch commands", () {
        final editingValue = EventSourcedAttributedTextEditingValue(
          AttributedTextEditingValue(
            text: AttributedText(text: ""),
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );

        // Run a batch command with multiple inner commands.
        editingValue
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "a")))
          ..execute(BatchCommand([
            InsertTextAtCaretCommand(AttributedText(text: "b")),
            InsertTextAtCaretCommand(AttributedText(text: "c")),
          ]))
          ..execute(InsertTextAtCaretCommand(AttributedText(text: "d")));
        expect(editingValue.text.text, "abcd");

        // Undo the batch command.
        editingValue.undo();
        expect(editingValue.text.text, "abc");
        editingValue.undo();
        expect(editingValue.text.text, "a");

        // Redo the batch command.
        editingValue.redo();
        expect(editingValue.text.text, "abc");
      });
    });
  });
}
