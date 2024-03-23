import 'package:super_editor_quill/super_editor_quill.dart';
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

      test('making last character bold results in correct document state', () {
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
      });

      test(
          'making the whole line of text bold results in correct document state',
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

        applier.apply(editor, Delta()..retain(3, {'bold': true}));
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
          'making two whole lines of text bold results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: 'node-1', text: AttributedText('abc')),
            ParagraphNode(id: 'node-2', text: AttributedText('def')),
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

        applier.apply(
          editor,
          Delta()
            ..retain(3, {'bold': true})
            ..retain(1)
            ..retain(3, {'bold': true}),
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
            ParagraphNode(
              id: 'node-2',
              text: AttributedText(
                'def',
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
          'making an already bold line of text unbold results in correct document state',
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

        applier.apply(editor, Delta()..retain(3, {'bold': null}));
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

      test('making "abc" italic one by one results in correct document state',
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

        applier.apply(editor, Delta()..retain(1, {'italic': true}));
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
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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
            ..retain(1, {'italic': true}),
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
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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
            ..retain(1, {'italic': true}),
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
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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
          'making already italic "abc" unitalic one by one results in correct document state',
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
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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

        applier.apply(editor, Delta()..retain(1, {'italic': null}));
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
                      attribution: italicsAttribution,
                      offset: 1,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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
            ..retain(1, {'italic': null}),
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
                      attribution: italicsAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
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
            ..retain(1, {'italic': null}),
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
          'making "abc" underlined one by one results in correct document state',
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

        applier.apply(editor, Delta()..retain(1, {'underline': true}));
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
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
            ..retain(1, {'underline': true}),
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
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
            ..retain(1, {'underline': true}),
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
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
          'making already underlined "abc" un-underlined one by one results in correct document state',
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
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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

        applier.apply(editor, Delta()..retain(1, {'underline': null}));
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
                      attribution: underlineAttribution,
                      offset: 1,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
            ..retain(1, {'underline': null}),
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
                      attribution: underlineAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
            ..retain(1, {'underline': null}),
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

      test('making "abc" linked one by one results in correct document state',
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

        applier.apply(
          editor,
          Delta()..retain(1, {'link': 'https://example.com'}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(1, {'link': 'https://example.com'}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(1, {'link': 'https://example.com'}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
          'making already linked "abc" un-linked one by one results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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

        applier.apply(editor, Delta()..retain(1, {'link': null}));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 1,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(1, {'link': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 2,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(1, {'link': null}),
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
          'making the whole paragraph linked and unlinked results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
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

        applier.apply(
          editor,
          Delta()..retain(3, {'link': 'https://example.com'}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        applier.apply(editor, Delta()..retain(3, {'link': null}));
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
          'making the whole paragraph unlinked over multiple lines results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText(
                'def',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
            ParagraphNode(
              id: 'node-3',
              text: AttributedText(
                'ghi',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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

        applier.apply(
          editor,
          Delta()..retain(3, {'link': null}),
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
              text: AttributedText(
                'def',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                  ],
                ),
              ),
            ),
            ParagraphNode(
              id: 'node-3',
              text: AttributedText(
                'ghi',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(4)
            ..retain(3, {'link': null}),
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
              text: AttributedText(
                'ghi',
                AttributedSpans(
                  attributions: [
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: LinkAttribution(
                        url: Uri.parse('https://example.com'),
                      ),
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
            ..retain(8)
            ..retain(3, {'link': null}),
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
              text: AttributedText('ghi'),
            ),
          ],
        );
      });

      test(
          'removing bold attributions from a paragraph that has multiple attributions applied results in correct document state',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    // bold
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
                    // italics
                    SpanMarker(
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                    // underline
                    SpanMarker(
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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

        applier.apply(editor, Delta()..retain(3, {'bold': null}));
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText(
                'abc',
                AttributedSpans(
                  attributions: const [
                    // italics
                    SpanMarker(
                      attribution: italicsAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: italicsAttribution,
                      offset: 2,
                      markerType: SpanMarkerType.end,
                    ),
                    // underline
                    SpanMarker(
                      attribution: underlineAttribution,
                      offset: 0,
                      markerType: SpanMarkerType.start,
                    ),
                    SpanMarker(
                      attribution: underlineAttribution,
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
    });

    group('paragraph block type conversions', () {
      test(
          'converting a paragraph to heading 1 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 1 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 1}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header1Attribution},
            ),
          ],
        );

        // Remove header 1 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting a paragraph to heading 2 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 2 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 2}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header2Attribution},
            ),
          ],
        );

        // Remove header 2 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting a paragraph to heading 3 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 3 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 3}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header3Attribution},
            ),
          ],
        );

        // Remove header 3 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting a paragraph to heading 4 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 4 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 4}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header4Attribution},
            ),
          ],
        );

        // Remove header 4 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting a paragraph to heading 5 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 5 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 5}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header5Attribution},
            ),
          ],
        );

        // Remove header 5 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting a paragraph to heading 6 and back results in correct document states',
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
          reactionPipeline: [...defaultEditorReactions],
        );

        // Initial state
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );

        // Add header 6 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 6}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header6Attribution},
            ),
          ],
        );

        // Remove header 6 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });

      test(
          'converting three paragraphs to heading 1 and back results in correct document states',
          () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: 'node-1', text: AttributedText('abc')),
            ParagraphNode(id: 'node-2', text: AttributedText('def')),
            ParagraphNode(id: 'node-3', text: AttributedText('ghi')),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [...defaultRequestHandlers],
          reactionPipeline: [...defaultEditorReactions],
        );

        // Add header 1 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': 1})
            ..retain(3)
            ..retain(1, {'header': 1})
            ..retain(3)
            ..retain(1, {'header': 1}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': header1Attribution},
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
              metadata: {'blockType': header1Attribution},
            ),
            ParagraphNode(
              id: 'node-3',
              text: AttributedText('ghi'),
              metadata: {'blockType': header1Attribution},
            ),
          ],
        );

        // Remove header 1 attribution
        applier.apply(
          editor,
          Delta()
            ..retain(3)
            ..retain(1, {'header': null})
            ..retain(3)
            ..retain(1, {'header': null})
            ..retain(3)
            ..retain(1, {'header': null}),
        );
        expect(
          document.nodes,
          [
            ParagraphNode(
              id: 'node-1',
              text: AttributedText('abc'),
              metadata: {'blockType': paragraphAttribution},
            ),
            ParagraphNode(
              id: 'node-2',
              text: AttributedText('def'),
              metadata: {'blockType': paragraphAttribution},
            ),
            ParagraphNode(
              id: 'node-3',
              text: AttributedText('ghi'),
              metadata: {'blockType': paragraphAttribution},
            ),
          ],
        );
      });
    });
  });
}
