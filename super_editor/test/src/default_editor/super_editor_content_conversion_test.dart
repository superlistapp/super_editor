import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/supereditor_inspector.dart';
import '../../super_editor/supereditor_robot.dart';
import '../../test_tools.dart';
import 'document_input_ime_test.dart';

void main() {
  group('SuperEditor', () {
    group('link conversion', () {
      group('on desktop', () {
        // This is not neccessary a desktop platform test suite, but it utilizes the
        // simulation of pasting on desktop
        // Note: This covers cases on mobile as well, so separated tests for mobile
        // is not necessary
        group('recognizes links in pasted code', () {
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
            // Simulate the user pasting content from clipboard
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
            // Simulate the user pasting content from clipboard
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
            // Simulate the user pasting content from clipboard
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
            // Simulate the user pasting content from clipboard
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
            // Simulate the user pasting content from clipboard
            await tester.pressCmdV();

            // Ensure that the link is unchanged
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown(
                  "Link: [https://flutter.dev](https://flutter.dev)[https://google.com](https://google.com)"),
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
            // Simulate the user pasting content from clipboard
            await tester.pressCmdV();

            // Ensure that the link is unchanged
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown(
                  "[https://google.com](https://google.com)Link: [https://flutter.dev](https://flutter.dev)"),
            );
          });
        });

        group('inserting a space character', () {
          testWidgetsOnMobile('automatically converts a URL into a link', (tester) async {
            // Configure and render a document.
            await tester //
                .createDocument()
                .withSingleEmptyParagraph()
                .pump();

            // Place the caret in the first paragraph at the start of the link.
            await tester.placeCaretInParagraph('1', 0);

            // Type a URL followed by a space and some text.
            await tester.typeKeyboardText('Go to https://flutter.dev to learn Flutter.');

            // Ensure that the URL is converted into link
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown('Go to [https://flutter.dev](https://flutter.dev) to learn Flutter.'),
            );
          });

          // Adding [LinkAttribution] to a position that already has it
          // could cause spans conflict, which potentially leads to errors.
          // This test prevents that regression
          testWidgetsOnMobile('it does nothing to an existing link', (tester) async {
            // Configure and render a document.
            await tester //
                .createDocument()
                .withCustomContent(_singleParagraphWithLinkDoc())
                .pump();

            // Place the caret at This text: https://flutter.dev|.
            await tester.placeCaretInParagraph('1', 18);

            // Type a space followed by some text.
            await tester.typeKeyboardText(' is already a link.');

            // Ensure that the link is unchanged
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown('[https://google.com](https://google.com) is already a link.'),
            );
          });

          testWidgetsOnMobile('it converts only the URL after the existing link', (tester) async {
            // Configure and render a document.
            await tester //
                .createDocument()
                .withCustomContent(_singleParagraphWithLinkDoc())
                .pump();

            // Place the caret at the end of the link
            await tester.placeCaretInParagraph('1', 18);

            // Type a URL followed by a space and some text.
            await tester.typeKeyboardText('https://flutter.dev are 2 separated links');

            // Ensure that it only converts the newly typed in link
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown(
                '[https://google.com](https://google.com)[https://flutter.dev](https://flutter.dev) are 2 separated links',
              ),
            );
          });
        });
      });

      group('on mobile', () {
        group('inserting a space character', () {
          testWidgetsOnMobile('automatically converts a URL into a link', (tester) async {
            // Configure and render a document.
            final testerDocumentContext = await tester //
                .createDocument()
                .withSingleEmptyParagraph()
                .pump();

            final softwareKeyboardHandler = SoftwareKeyboardHandler(
              composer: testerDocumentContext.editContext.composer,
              editor: testerDocumentContext.editContext.editor,
              commonOps: testerDocumentContext.editContext.commonOps,
            );

            // Place the caret in the first paragraph
            await tester.placeCaretInParagraph('1', 0);

            // Type a URL followed by a space and some text.
            await tester.textToType(
              softwareKeyboardHandler: softwareKeyboardHandler,
              text: 'Go to https://flutter.dev to learn Flutter.',
              existingText: '',
              insertionOffset: 0,
            );

            // Ensure that the URL is converted into link
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown('Go to [https://flutter.dev](https://flutter.dev) to learn Flutter.'),
            );
          });

          testWidgetsOnMobile('it does nothing to an existing link', (tester) async {
            // Adding [LinkAttribution] to a position that already has it
            // could cause spans conflict, which potentially leads to errors.
            // This test prevents that regression

            // Configure and render a document.
            final testerDocumentContext = await tester //
                .createDocument()
                .withCustomContent(_singleParagraphWithLinkDoc())
                .pump();

            final softwareKeyboardHandler = SoftwareKeyboardHandler(
              composer: testerDocumentContext.editContext.composer,
              editor: testerDocumentContext.editContext.editor,
              commonOps: testerDocumentContext.editContext.commonOps,
            );

            // Place the caret at the end of the link.
            await tester.placeCaretInParagraph('1', 18);

            // Type a space followed by some text.
            await tester.textToType(
              softwareKeyboardHandler: softwareKeyboardHandler,
              text: ' is already a link.',
              existingText: 'https://google.com',
              insertionOffset: 18,
            );

            // Ensure that the link is unchanged
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown('[https://google.com](https://google.com) is already a link.'),
            );
          });

          testWidgetsOnMobile('it converts only the URL after the existing link', (tester) async {
            // Configure and render a document.
            final testerDocumentContext = await tester //
                .createDocument()
                .withCustomContent(_singleParagraphWithLinkDoc())
                .pump();

            final softwareKeyboardHandler = SoftwareKeyboardHandler(
              composer: testerDocumentContext.editContext.composer,
              editor: testerDocumentContext.editContext.editor,
              commonOps: testerDocumentContext.editContext.commonOps,
            );

            // Place the caret at the end of the link
            await tester.placeCaretInParagraph('1', 18);

            // Type a URL followed by a space and some text.
            await tester.textToType(
              softwareKeyboardHandler: softwareKeyboardHandler,
              text: 'https://flutter.dev are 2 separated links',
              existingText: 'https://google.com',
              insertionOffset: 18,
            );

            // Ensure that it only converts the newly typed in link
            expect(
              SuperEditorInspector.findDocument(),
              equalsMarkdown(
                '[https://google.com](https://google.com)[https://flutter.dev](https://flutter.dev) are 2 separated links',
              ),
            );
          });
        });
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
