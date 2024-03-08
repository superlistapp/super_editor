import 'package:quill_delta/quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/delta_applier.dart';
import 'package:test/test.dart';

void main() {
  group('DeltaApplier', () {
    var nodeCount = 0;
    late DeltaApplier applier;

    setUp(() {
      nodeCount = 0;
      applier = DeltaApplier(
        idGenerator: () {
          nodeCount++;
          return 'node-$nodeCount';
        },
      );
    });

    group('simple plain text tests', () {
      test('inserting "\\n" results in correct document state', () {
        final document = MutableDocument();
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        applier.apply(editor, Delta()..insert('\n'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );
      });

      test('inserting "abc" one by one results in correct document state', () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        applier.apply(
          editor,
          Delta()
            ..insert('a')
            ..retain(1)
            ..insert('b')
            ..retain(2)
            ..insert('c'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, then deleting it as single change, results in correct document state',
          () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // delete "abc"
        applier.apply(editor, Delta()..delete(3));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );
      });

      test(
          'inserting "abc" one by one, then deleting it one by one, results in correct document state',
          () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "a"
        applier.apply(
          editor,
          Delta()
            ..insert('a')
            ..retain(1),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('a'),
            ),
          ],
        );

        // insert "b"
        applier.apply(
          editor,
          Delta()
            ..retain(1)
            ..insert('b'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('ab'),
            ),
          ],
        );

        // insert "c"
        applier.apply(
          editor,
          Delta()
            ..retain(2)
            ..insert('c'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // delete "c"
        applier.apply(
          editor,
          Delta()
            ..retain(2)
            ..delete(1),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('ab'),
            ),
          ],
        );

        // delete "b"
        applier.apply(
          editor,
          Delta()
            ..retain(1)
            ..delete(1),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('a'),
            ),
          ],
        );

        // delete "a"
        applier.apply(editor, Delta()..delete(1));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, then deleting "b", results in correct document state',
          () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // delete "b"
        applier.apply(
          editor,
          Delta()
            ..retain(1)
            ..delete(1),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('ac'),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, then deleting "a", results in correct document state',
          () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // delete "a"
        applier.apply(editor, Delta()..delete(1));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('bc'),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, then deleting "a", results in correct document state',
          () {
        final document = MutableDocument.empty('node-1');
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // delete "a"
        applier.apply(editor, Delta()..delete(1));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('bc'),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, then inserting a newline, results in correct document state',
          () {
        final document = MutableDocument();
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "\n" to create an empty paragraph
        applier.apply(editor, Delta()..insert('\n'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // insert newline
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..insert('\n'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "def" on the new paragraph
        applier.apply(
          editor,
          Delta()
            ..retain(4)
            ..insert('def'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, inserting a newline, inserting "def", and inserting newline results in correct document state',
          () {
        final document = MutableDocument();
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "\n" to create an empty paragraph
        applier.apply(editor, Delta()..insert('\n'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // insert newline
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..insert('\n'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "def" on the new paragraph
        applier.apply(
          editor,
          Delta()
            ..retain(4)
            ..insert('def'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
            ),
          ],
        );

        // insert newline
        applier.apply(
          editor,
          Delta()
            ..retain(7)
            ..insert('\n'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
            ),
            ParagraphNode(
              id: 'node-3',
              text: AttributedText(''),
            ),
          ],
        );
      });

      test(
          'inserting "abc" as single change, inserting a newline, inserting "def", and deleting "f" results in correct document state',
          () {
        final document = MutableDocument();
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        // insert "\n" to create an empty paragraph
        applier.apply(editor, Delta()..insert('\n'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "abc"
        applier.apply(editor, Delta()..insert('abc'));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );

        // insert newline
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..insert('\n'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText(''),
            ),
          ],
        );

        // insert "def" on the new paragraph
        applier.apply(
          editor,
          Delta()
            ..retain(4)
            ..insert('def'),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
            ),
          ],
        );

        // delete "f"
        applier.apply(
          editor,
          Delta()
            ..retain(6)
            ..delete(1),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('de'),
            ),
          ],
        );
      });
    });

    group('rich text tests', () {
      test('making "abc" bold one by one results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [ParagraphNode(id: 'node-1', text: AttributedText('abc'))],
        );
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        applier.apply(editor, Delta()..retain(1, {'bold': true}));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        applier.apply(
          editor,
          Delta()
            ..retain(1)
            ..retain(1, {'bold': true}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 1,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        applier.apply(
          editor,
          Delta()
            ..retain(2)
            ..retain(1, {'bold': true}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      });

      test(
          'making already bold "abc" unbold one by one results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
        );

        applier.apply(editor, Delta()..retain(1, {'bold': null}));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 1,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        applier.apply(
          editor,
          Delta()
            ..retain(1)
            ..retain(1, {'bold': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: boldAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        applier.apply(
          editor,
          Delta()
            ..retain(2)
            ..retain(1, {'bold': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
            ),
          ],
        );
      });
    });
  });
}
