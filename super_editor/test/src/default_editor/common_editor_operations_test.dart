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

        // Type some text by simulating hardware keyboard key presses.
        await tester.pressCmdV();

        // Ensure that the clipboard text was pasted into the SuperTextField
        expect(
          SuperEditorInspector.findTextInParagraph("1").text,
          'Link: https://flutter.dev and link: https://pub.dev',
        );

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findTextInParagraph("1").spans.getAttributionSpansInRange(
                attributionFilter: (_) => true,
                start: 0,
                end: 51,
              ),
          {
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://flutter.dev')),
              start: 6,
              end: 24,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://pub.dev')),
              start: 36,
              end: 50,
            )
          },
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

        // Type some text by simulating hardware keyboard key presses.
        await tester.pressCmdV();

        // Ensure that the clipboard text was pasted into the SuperTextField
        expect(SuperEditorInspector.findTextInParagraph("1").text,
            'Pasted content: Link: https://flutter.dev and link: https://pub.dev.');

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findTextInParagraph("1").spans.getAttributionSpansInRange(
                attributionFilter: (_) => true,
                start: 0,
                end: 67,
              ),
          {
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://flutter.dev')),
              start: 22,
              end: 40,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://pub.dev')),
              start: 52,
              end: 66,
            )
          },
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

        // Type some text by simulating hardware keyboard key presses.
        await tester.pressCmdV();

        // Ensure that the clipboard text was pasted into the SuperTextField
        expect(SuperEditorInspector.findTextInParagraph("1").text,
            'https://gooLink: https://flutter.dev and link: https://pub.devgle.com');

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findTextInParagraph("1").spans.getAttributionSpansInRange(
                attributionFilter: (_) => true,
                start: 0,
                end: 69,
              ),
          {
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://google.com')),
              start: 0,
              end: 10,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://flutter.dev')),
              start: 17,
              end: 35,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://pub.dev')),
              start: 47,
              end: 61,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://google.com')),
              start: 62,
              end: 68,
            ),
          },
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

        // Type some text by simulating hardware keyboard key presses.
        await tester.pressCmdV();

        // Ensure that the clipboard text was pasted into the SuperTextField
        expect(
          SuperEditorInspector.findTextInParagraph("1").text,
          'Link: https://flutter.devhttps://google.com',
        );

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findTextInParagraph("1").spans.getAttributionSpansInRange(
                attributionFilter: (_) => true,
                start: 0,
                end: 43,
              ),
          {
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://flutter.dev')),
              start: 6,
              end: 24,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://google.com')),
              start: 25,
              end: 42,
            ),
          },
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

        // Type some text by simulating hardware keyboard key presses.
        await tester.pressCmdV();

        // Ensure that the clipboard text was pasted into the SuperTextField
        expect(
          SuperEditorInspector.findTextInParagraph("1").text,
          'https://google.comLink: https://flutter.dev',
        );

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findTextInParagraph("1").spans.getAttributionSpansInRange(
                attributionFilter: (_) => true,
                start: 0,
                end: 43,
              ),
          {
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://google.com')),
              start: 0,
              end: 17,
            ),
            AttributionSpan(
              attribution: LinkAttribution(url: Uri.parse('https://flutter.dev')),
              start: 24,
              end: 42,
            ),
          },
        );
      });
    });
  });
}
