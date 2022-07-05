import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/supereditor_inspector.dart';
import '../../super_editor/supereditor_robot.dart';
import '../../test_tools.dart';

void main() {
  group("Common editor operations", () {
    group("deletion", () {
      test("from text node (inclusive) to text node (partial)", () {
        final document = MutableDocument(nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(
              text: 'This is a blockquote!',
            ),
          ),
          ParagraphNode(
            id: "2",
            text: AttributedText(
                text:
                    'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
          ),
        ]);
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: TextNodePosition(offset: 50),
            ),
          ),
        );
        final commonOps = CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );

        commonOps.deleteSelection();

        final doc = editor.document;
        expect(doc.nodes.length, 1);
        expect(doc.nodes.first.id, "2");
        expect(composer.selection!.extent.nodeId, "2");
        expect(composer.selection!.extent.nodePosition, const TextNodePosition(offset: 0));
      });

      test("from block node (inclusive) to text node (partial)", () {
        final document = MutableDocument(nodes: [
          HorizontalRuleNode(id: "1"),
          ParagraphNode(
            id: "2",
            text: AttributedText(
                text:
                    'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
          ),
        ]);
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: TextNodePosition(offset: 50),
            ),
          ),
        );
        final commonOps = CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );

        commonOps.deleteSelection();

        final doc = editor.document;
        expect(doc.nodes.length, 1);
        expect(doc.nodes.first.id, "2");
        expect(composer.selection!.extent.nodeId, "2");
        expect(composer.selection!.extent.nodePosition, const TextNodePosition(offset: 0));
      });

      test("from text node (partial) to block node (inclusive)", () {
        final document = MutableDocument(nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(
                text:
                    'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
          ),
          HorizontalRuleNode(id: "2"),
        ]);
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 50),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );
        final commonOps = CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );

        commonOps.deleteSelection();

        final doc = editor.document;
        expect(doc.nodes.length, 1);
        expect(doc.nodes.first.id, "1");
        expect(composer.selection!.extent.nodeId, "1");
        expect(composer.selection!.extent.nodePosition, const TextNodePosition(offset: 50));
      });

      test("from block node (inclusive) to block node (inclusive)", () {
        final document = MutableDocument(nodes: [
          HorizontalRuleNode(id: "1"),
          HorizontalRuleNode(id: "2"),
        ]);
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );
        final commonOps = CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );

        commonOps.deleteSelection();

        final doc = editor.document;
        expect(doc.nodes.length, 1);
        expect(doc.nodes.first, isA<ParagraphNode>());
        expect(doc.nodes.first.id, "1");
        expect(composer.selection!.extent.nodePosition, const TextNodePosition(offset: 0));
      });
    });

    group('pasting', () {
      group("apply composer attribution to pasted text", () {
        testWidgetsOnMac('when pasting into an empty paragraph', (tester) async {
          tester.simulateClipboard();
          tester.setSimulatedClipboardContent("Hello world");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .forDesktop()
              .pump();

          await tester.placeCaretInParagraph("1", 0);

          // Toggle bold attribution before pasting
          await tester.pressCmdB();
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          await tester.typeKeyboardText('. Hello Mars');

          // Ensure that URLs are converted into links
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              '**Hello world. Hello Mars**',
            ),
          );
        });

        testWidgetsOnMac('when pasting at the start of text', (tester) async {
          tester.simulateClipboard();
          tester.setSimulatedClipboardContent("Hello world");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText(text: ". Hello other planets")),
                ],
              ))
              .forDesktop()
              .pump();

          await tester.placeCaretInParagraph("1", 0);

          // Toggle bold attribution before pasting
          await tester.pressCmdB();
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          await tester.typeKeyboardText('. Hello Mars');

          // Ensure that bold attribution is applied
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              '**Hello world. Hello Mars**. Hello other planets',
            ),
          );
        });

        testWidgetsOnMac('when pasting in the middle of text', (tester) async {
          tester.simulateClipboard();
          tester.setSimulatedClipboardContent("world. Hello");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText(text: "Hello  other planets")),
                ],
              ))
              .forDesktop()
              .pump();

          // Tap to place the caret at 'Hello | other planets'
          await tester.placeCaretInParagraph("1", 6);

          // Toggle bold attribution before pasting
          await tester.pressCmdB();
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          await tester.typeKeyboardText(' Mars. Hello');

          // Ensure that bold attribution is applied
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Hello **world. Hello Mars. Hello** other planets',
            ),
          );
        });

        testWidgetsOnMac('when pasting at the end of text', (tester) async {
          tester.simulateClipboard();
          tester.setSimulatedClipboardContent("Hello world");

          // Configure and render a document.
          await tester //
              .createDocument()
              .withCustomContent(MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText(text: "Hello Mars. ")),
                ],
              ))
              .forDesktop()
              .pump();

          // Tap to place the caret at the end of text
          await tester.placeCaretInParagraph("1", 12);

          // Toggle bold attribution before pasting
          await tester.pressCmdB();
          // Simulate the user pasting content from clipboard
          await tester.pressCmdV();

          await tester.typeKeyboardText('. Hello other planets.');

          // Ensure that bold attribution is applied
          expect(
            SuperEditorInspector.findDocument(),
            equalsMarkdown(
              'Hello Mars. **Hello world. Hello other planets.**',
            ),
          );
        });
      });

      testWidgetsOnMac('splits a link in two when pasting in the middle of the link', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(_singleParagraphWithLinkDoc())
            .forDesktop()
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 11);
        // Simulate the user pasting content from clipboard
        await tester.pressCmdV();

        // Ensure that the link is splitted and not expanded
        // Pasted URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown('[https://goo](https://google.com)Link: [https://flutter.dev](https://flutter.dev) '
              'and link: [https://pub.dev](https://pub.dev)[gle.com](https://google.com)'),
        );
      });
    });
  });
}

MutableDocument _singleParagraphWithLinkDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(
          text: "https://google.com",
          spans: AttributedSpans(
            attributions: [
              SpanMarker(
                attribution: LinkAttribution(url: Uri.parse('https://google.com')),
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: LinkAttribution(url: Uri.parse('https://google.com')),
                offset: 17,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      )
    ],
  );
}
