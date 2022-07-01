import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/supereditor_inspector.dart';
import '../../super_editor/supereditor_robot.dart';
import '../../test_tools.dart';

void main() {
  // This test group covers cases related to link encoding when pasting. This
  // is not neccessary a desktop platform test, but it utilizes the simulation
  // of pasting on desktop
  //
  // Note: This covers cases on mobile as well, so separated tests for mobile
  // is not necessary
  group('SuperEditor', () {
    group("recognizes links in pasted code", () {
      testWidgetsOnMac('when pasting into an empty paragraph', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .forDesktop()
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

      testWidgetsOnMac('when pasting at the start of text', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText(text: "Some text")),
              ],
            ))
            .forDesktop()
            .pump();

        // Tap to place the caret at `|Some text` in the paragraph.
        await tester.placeCaretInParagraph("1", 0);

        await tester.pressCmdV();

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Link: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)Some text',
          ),
        );
      });

      testWidgetsOnMac('when pasting in the middle of text', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText(text: "Some text")),
              ],
            ))
            .forDesktop()
            .pump();

        // Tap to place the caret at `Some te|xt` in the paragraph.
        await tester.placeCaretInParagraph("1", 7);

        await tester.pressCmdV();

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Some teLink: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)xt',
          ),
        );
      });

      testWidgetsOnMac('when pasting at the end of text', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev and link: https://pub.dev");

        // Configure and render a document.
        await tester
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(id: "1", text: AttributedText(text: "Some text")),
              ],
            ))
            .forDesktop()
            .pump();

        // Tap to place the caret at `Some text|` in the paragraph.
        await tester.placeCaretInParagraph("1", 9);

        await tester.pressCmdV();

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Some textLink: [https://flutter.dev](https://flutter.dev) and link: [https://pub.dev](https://pub.dev)',
          ),
        );
      });

      testWidgetsOnMac('when pasting at the start of a link', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(_singleParagraphWithLinkDoc())
            .forDesktop()
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

      testWidgetsOnMac('when pasting at the end of a link', (tester) async {
        tester.simulateClipboard();
        tester.setSimulatedClipboardContent("Link: https://flutter.dev");

        // Configure and render a document.
        await tester //
            .createDocument()
            .withCustomContent(_singleParagraphWithLinkDoc())
            .forDesktop()
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

        await tester.pressCmdV();

        // Ensure that the link is not being expanded and splitted. Pasted URLs are converted
        // into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown('[https://goo](https://google.com)Link: [https://flutter.dev](https://flutter.dev) '
              'and link: [https://pub.dev](https://pub.dev)[gle.com](https://google.com)'),
        );
      });
    });

    group("apply toggled attribution to pasted text", () {
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

        await tester.pressCmdV();

        await tester.typeKeyboardText('. Hello Mars');

        // Ensure that URLs are converted into links
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

        await tester.pressCmdV();

        await tester.typeKeyboardText(' Mars. Hello');

        // Ensure that URLs are converted into links
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

        await tester.pressCmdV();

        await tester.typeKeyboardText('. Hello other planets.');

        // Ensure that URLs are converted into links
        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(
            'Hello Mars. **Hello world. Hello other planets.**',
          ),
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
