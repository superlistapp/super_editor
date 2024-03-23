import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_quill/src/delta_document_change_listener.dart';

class _Boilerplate extends StatefulWidget {
  const _Boilerplate({
    this.paragraphNodeId,
    required this.onDeltaChangeDetected,
  });

  final String? paragraphNodeId;
  final void Function(Delta) onDeltaChangeDetected;

  @override
  State<_Boilerplate> createState() => _BoilerplateState();
}

class _BoilerplateState extends State<_Boilerplate> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  @override
  void initState() {
    super.initState();
    _document = MutableDocument.empty(widget.paragraphNodeId);
    final changeListener = DeltaDocumentChangeListener(
      peekAtDocument: () =>
          MutableDocument(nodes: List.unmodifiable(_document.nodes)),
      onDeltaChangeDetected: widget.onDeltaChangeDetected,
    );
    _document.addListener(changeListener.call);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [...defaultRequestHandlers],
    );
  }

  @override
  void dispose() {
    _document.dispose();
    _composer.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              return SuperEditor(
                autofocus: true,
                editor: _editor,
                document: _document,
                composer: _composer,
              );
            },
          ),
        ],
      ),
    );
  }
}

void main() {
  group('DeltaEditListener', () {
    final changeDeltas = <Delta>[];
    var document = Delta();

    setUp(() {
      changeDeltas.clear();
      document = Delta();
    });

    Future<void> pumpEditor(WidgetTester tester, {String? paragraphNodeId}) {
      return tester.pumpWidget(
        _Boilerplate(
          paragraphNodeId: paragraphNodeId,
          onDeltaChangeDetected: (change) {
            changeDeltas.add(change);
            document = document.compose(change);
          },
        ),
      );
    }

    group('simple plain text tests', () {
      testWidgets('typing "abc" results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester);
        await tester.typeTextAdaptive('abc');

        expect(document, Delta()..insert('abc'));
        expect(
          changeDeltas,
          [
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),
          ],
        );
      });

      testWidgets(
          'typing "abc" and pressing backspace three times results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester);
        await tester.typeTextAdaptive('abc');
        await tester.pressBackspaceAdaptive();
        await tester.pressBackspaceAdaptive();
        await tester.pressBackspaceAdaptive();

        expect(document, Delta());
        expect(
          changeDeltas,
          [
            // First, we insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...and then we delete it, also letter by letter.
            Delta()
              ..retain(2)
              ..delete(1),
            Delta()
              ..retain(1)
              ..delete(1),
            Delta()..delete(1),
          ],
        );
      });

      testWidgets(
          'typing "abc", moving cursor between "b" and "c", and pressing backspace one time results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.placeCaretInParagraph('node-1', 2);
        await tester.pressBackspaceAdaptive();

        expect(document, Delta()..insert('ac'));
        expect(
          changeDeltas,
          [
            // First, we insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...and then we delete the letter "b".
            Delta()
              ..retain(1)
              ..delete(1),
          ],
        );
      });

      testWidgets(
          'typing "abc", moving cursor between "a" and "b", and pressing backspace one time results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.placeCaretInParagraph('node-1', 1);
        await tester.pressBackspaceAdaptive();

        expect(document, Delta()..insert('bc'));
        expect(
          changeDeltas,
          [
            // First, we insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...and then we delete the letter "a".
            Delta()..delete(1),
          ],
        );
      });

      testWidgets(
          'typing "abc", moving cursor before "a", and pressing backspace one time results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.placeCaretInParagraph('node-1', 0);
        await tester.pressBackspaceAdaptive();

        expect(document, Delta()..insert('abc'));
        expect(
          changeDeltas,
          [
            // We insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...and that's all. Placing cursor before "a" and pressing backspace
            // does not result in a change delta.
          ],
        );
      });

      testWidgets(
          'typing "abc", pressing enter, and typing "def" results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.pressEnterAdaptive();
        await tester.typeTextAdaptive('def');

        expect(document, Delta()..insert('abc\ndef'));
        expect(
          document,
          Delta()
            ..insert('abc\n')
            ..insert('def'),
        );
        expect(
          changeDeltas,
          [
            // We insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...then a newline...
            Delta()
              ..retain(3)
              ..insert('\n'),

            // ...and then "def" letter-by-letter.
            Delta()
              ..retain(4)
              ..insert('d'),
            Delta()
              ..retain(5)
              ..insert('e'),
            Delta()
              ..retain(6)
              ..insert('f'),
          ],
        );
      });

      testWidgets(
          'typing "abc", pressing enter, typing "def", and pressing backspace four times results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.pressEnterAdaptive();
        await tester.typeTextAdaptive('def');
        await tester.pressBackspaceAdaptive();
        await tester.pressBackspaceAdaptive();
        await tester.pressBackspaceAdaptive();
        await tester.pressBackspaceAdaptive();

        expect(document, Delta()..insert('abc'));
        expect(
          changeDeltas,
          [
            // We insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...then a newline...
            Delta()
              ..retain(3)
              ..insert('\n'),

            // ...and then "def" letter-by-letter.
            Delta()
              ..retain(4)
              ..insert('d'),
            Delta()
              ..retain(5)
              ..insert('e'),
            Delta()
              ..retain(6)
              ..insert('f'),

            // Finally, "\ndef" is deleted.
            Delta()
              ..retain(6)
              ..delete(1),
            Delta()
              ..retain(5)
              ..delete(1),
            Delta()
              ..retain(4)
              ..delete(1),
            Delta()
              ..retain(3)
              ..delete(1),
          ],
        );
      });

      testWidgets(
          'typing "abc", pressing enter, typing "def", selecting all, and pressing backspace results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.pressEnterAdaptive();
        await tester.typeTextAdaptive('def');
        await tester.pressCtlA();
        await tester.pressBackspaceAdaptive();

        expect(document, Delta());
        // TODO: expect(document, Delta()..insert('\n'));
        expect(
          changeDeltas,
          [
            // We insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...then a newline...
            Delta()
              ..retain(3)
              ..insert('\n'),

            // ...and then "def" letter-by-letter.
            Delta()
              ..retain(4)
              ..insert('d'),
            Delta()
              ..retain(5)
              ..insert('e'),
            Delta()
              ..retain(6)
              ..insert('f'),

            // Finally, everything is deleted.
            Delta()..delete(7),
          ],
        );
      });

      testWidgets(
          'typing "abc", pressing enter, typing "def", pressing enter, and typing "ghi" results in correct change Deltas',
          (tester) async {
        await pumpEditor(tester, paragraphNodeId: 'node-1');
        await tester.typeTextAdaptive('abc');
        await tester.pressEnterAdaptive();
        await tester.typeTextAdaptive('def');
        await tester.pressEnterAdaptive();
        await tester.typeTextAdaptive('ghi');

        // TODO: expect(document, Delta()..insert('abc\ndef\nghi\n'));
        expect(document, Delta()..insert('abc\ndef\nghi'));
        expect(
          changeDeltas,
          [
            // We insert "abc" letter-by-letter...
            Delta()..insert('a'),
            Delta()
              ..retain(1)
              ..insert('b'),
            Delta()
              ..retain(2)
              ..insert('c'),

            // ...then a newline...
            Delta()
              ..retain(3)
              ..insert('\n'),

            // ...then "def" letter-by-letter...
            Delta()
              ..retain(4)
              ..insert('d'),
            Delta()
              ..retain(5)
              ..insert('e'),
            Delta()
              ..retain(6)
              ..insert('f'),

            // ...then a newline...
            Delta()
              ..retain(7)
              ..insert('\n'),

            // ...then "def" letter-by-letter...
            Delta()
              ..retain(8)
              ..insert('g'),
            Delta()
              ..retain(9)
              ..insert('h'),
            Delta()
              ..retain(10)
              ..insert('i'),
          ],
        );
      });
    });
  });
}

extension on WidgetTester {
  Future<void> pressBackspaceAdaptive() async {
    if (!testTextInput.hasAnyClients) {
      // There isn't any IME connections.
      // Type using the hardware keyboard.
      await pressBackspace();
      return;
    }

    await ime.backspace(getter: () => imeClientGetter());
  }
}
