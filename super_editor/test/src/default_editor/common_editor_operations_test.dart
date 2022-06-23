import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/supereditor_inspector.dart';
import '../../super_editor/supereditor_robot.dart';
import '../../test_tools.dart';
import '../_document_test_tools.dart';

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

    // This test group covers cases related to link encoding when pasting. This
    // is not neccessary a desktop platform test, but it utilizes the simulation
    // of pasting on desktop
    //
    // Note: This covers cases on mobile as well, so separated tests for mobile
    // is not necessary
    group('link encoding when pasting', () {
      testWidgetsOnMac('converts URLs on an empty paragraph', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .forDesktop()
            .autoFocus(true)
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdV();

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Link: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)',
          ),
        );
      });

      testWidgetsOnMac('converts URLs on an existing paragraph', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText(text: "Pasted content: .")),
              ],
            ))
            .forDesktop()
            .autoFocus(true)
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 16);

        await tester.pressCmdV();

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Pasted content: Link: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev).',
          ),
        );
      });

      testWidgetsOnMac('when pasting in a link, split the existing link and convert URLs', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleLinkParagraph()
            .forDesktop()
            .autoFocus(true)
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 11);

        await tester.pressCmdV();

        // Ensure that the link is not being expanded and splitted. Pasted URLs are converted
        // into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown('[https://goo](https://google.com)Link: [https://flutter.dev](https://flutter.dev) '
              'and link: [https://pub.dev](https://pub.dev)[gle.com](https://google.com)'),
        );
      });

      testWidgetsOnMac('when pasting at the start of a link, convert URLs and prevent expanding link', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleLinkParagraph()
            .forDesktop()
            .autoFocus(true)
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdV();

        // Ensure that the link is not being expanded
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown("Link: [https://flutter.dev](https://flutter.dev)[https://google.com](https://google.com)"),
        );
      });

      testWidgetsOnMac('when pasting at the end of a link, convert URLs and prevent expanding link', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleLinkParagraph()
            .forDesktop()
            .autoFocus(true)
            .pump();

        // Tap to place the caret in the first paragraph.
        await tester.placeCaretInParagraph("1", 18);

        await tester.pressCmdV();

        // Ensure that the link is not being expanded
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown("[https://google.com](https://google.com)Link: [https://flutter.dev](https://flutter.dev)"),
        );
      });
    });
  });
}
