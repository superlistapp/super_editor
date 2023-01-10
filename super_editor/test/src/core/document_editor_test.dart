import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/test_documents.dart';

void main() {
  group('DocumentEditor', () {
    group('editing', () {
      test('throws exception when there is no command for a given request', () {
        final editor = DocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: ""))],
          ),
          requestHandlers: [],
        );

        expectLater(() {
          editor.execute(const InsertCharacterAtCaretRequest(character: "a"));
        }, throwsException);
      });

      test('executes a single command', () {
        final editor = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        DocumentChangeLog? changeLog;
        editor.document.addListener((newChangeLog) {
          changeLog = newChangeLog;
        });

        editor.execute(const InsertCharacterAtCaretRequest(character: "a"));

        expect(changeLog, isNotNull);
        expect(changeLog!.changes.length, 2);
        expect(changeLog!.changes.first, isA<NodeChangeEvent>());
        expect(changeLog!.changes.last, isA<SelectionChangeEvent>());
      });

      test('executes a series of commands', () {
        final editor = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        int changeLogCount = 0;
        int changeEventCount = 0;
        editor.document.addListener((newChangeLog) {
          changeLogCount += 1;
          changeEventCount += newChangeLog.changes.length;
        });

        editor
          ..execute(const InsertCharacterAtCaretRequest(character: "H"))
          ..execute(const InsertCharacterAtCaretRequest(character: "e"))
          ..execute(const InsertCharacterAtCaretRequest(character: "l"))
          ..execute(const InsertCharacterAtCaretRequest(character: "l"))
          ..execute(const InsertCharacterAtCaretRequest(character: "o"));

        expect(changeLogCount, 5);
        expect(changeEventCount, 10); // 2 events per character insertion
        expect((editor.document.getNodeAt(0) as ParagraphNode).text.text, "Hello");
      });

      test('executes multiple expanding commands', () {
        // This test ensures that if one command expands into multiple commands,
        // and those commands expand to additional commands, the overall command
        // order is what we expect.
        final editor = DocumentEditor(
          document: MutableDocument(
            nodes: [ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: ""))],
          ),
          requestHandlers: [
            (request) => request is _ExpandingCommandRequest ? _ExpandingCommand(request) : null,
          ],
        );
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        // TODO: get rid of magic strings
        editor.context.put("composer", composer);

        editor.execute(
          const _ExpandingCommandRequest(
            generationId: 0,
            batchId: 0,
            newCommandCount: 3,
            levelsOfGeneration: 3,
          ),
        );

        // Ensure that the commands printed the number and spacing that we expected,
        // given the expansion order.
        //
        // Each value is "(a.b)" where "a" is the generation, and "b" is the batch ID
        // within the generation. The output should look like a depth first tree
        // traversal.
        final paragraph = editor.document.getNodeAt(0) as ParagraphNode;
        expect(
          paragraph.text.text,
          '''(0.0)
  (1.0)
    (2.0)
      (3.0)
      (3.1)
      (3.2)
    (2.1)
      (3.0)
      (3.1)
      (3.2)
    (2.2)
      (3.0)
      (3.1)
      (3.2)
  (1.1)
    (2.0)
      (3.0)
      (3.1)
      (3.2)
    (2.1)
      (3.0)
      (3.1)
      (3.2)
    (2.2)
      (3.0)
      (3.1)
      (3.2)
  (1.2)
    (2.0)
      (3.0)
      (3.1)
      (3.2)
    (2.1)
      (3.0)
      (3.1)
      (3.2)
    (2.2)
      (3.0)
      (3.1)
      (3.2)''',
        );
      });
    });
  });
}

DocumentEditor _createStandardEditor({
  MutableDocument? initialDocument,
  DocumentSelection? initialSelection,
}) {
  final document = initialDocument ?? singleParagraphEmptyDoc();

  final editor = DocumentEditor(
    document: document,
    requestHandlers: defaultRequestHandlers,
  );

  final composer = DocumentComposer(initialSelection: initialSelection);
  // TODO: get rid of magic strings
  editor.context.put("composer", composer);

  return editor;
}

/// Request that runs a command, which spawns more commands, based on the
/// given [newCommandCount] and [levelsOfGeneration].
///
/// This request, and its command, are used to test the command spawning and
/// ordering behavior of [DocumentEditor] without finding real commands that
/// exemplify the necessary spawning behavior.
class _ExpandingCommandRequest implements EditorRequest {
  const _ExpandingCommandRequest({
    required this.generationId,
    required this.batchId,
    required this.newCommandCount,
    required this.levelsOfGeneration,
  });

  /// The generation of this request, e.g., `0` for the first generation,
  /// `1` for the second, etc.
  final int generationId;

  /// The ID of this request within its generation batch.
  ///
  /// If three requests are created within a newly spawned generation, then the
  /// first request to be generated will be given ID `0`, the second `1`, etc.
  final int batchId;

  /// The number of new commands that this request will generate (breadth of a tree).
  final int newCommandCount;

  /// The number of generations of commands that this request will generate (depth
  /// of a tree).
  final int levelsOfGeneration;
}

class _ExpandingCommand implements EditorCommand {
  const _ExpandingCommand(this.request);

  final _ExpandingCommandRequest request;

  @override
  List<DocumentChangeEvent> execute(EditorContext context, CommandExpander expandActiveCommand) {
    // TODO: get rid of magic strings
    final document = context.find<Document>("document");
    final paragraph = document.getNodeAt(0) as ParagraphNode;

    final changes = [
      ...InsertTextCommand(
        documentPosition: DocumentPosition(
          nodeId: paragraph.id,
          nodePosition: TextNodePosition(offset: paragraph.text.text.length),
        ),
        textToInsert:
            "${request.generationId > 0 ? "\n" : ""}${List.filled(request.generationId, "  ").join()}(${request.generationId}.${request.batchId})",
        attributions: {},
      ).execute(context, expandActiveCommand),
    ];

    if (request.levelsOfGeneration > 0) {
      for (int i = 0; i < request.newCommandCount; i += 1) {
        expandActiveCommand(
          _ExpandingCommand(
            _ExpandingCommandRequest(
              generationId: request.generationId + 1, // +1 for next generation
              batchId: i, // i'th member of this generation
              newCommandCount: request.newCommandCount,
              levelsOfGeneration: request.levelsOfGeneration - 1, // -1 generations to go
            ),
          ),
        );
      }
    }

    return changes;
  }
}
