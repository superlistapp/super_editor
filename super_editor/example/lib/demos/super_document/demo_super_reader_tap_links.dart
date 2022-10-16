import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Demo that displays a [SuperReader] with tappable links.
class SuperReaderTapLinksDemo extends StatefulWidget {
  const SuperReaderTapLinksDemo({Key? key}) : super(key: key);

  @override
  State<SuperReaderTapLinksDemo> createState() => _SuperReaderTapLinksDemoState();
}

class _SuperReaderTapLinksDemoState extends State<SuperReaderTapLinksDemo> implements UrlLauncherDelegate {
  late final Document _document;
  late final DocumentUrlLauncher _launchUrlDelegate;

  @override
  void initState() {
    super.initState();
    _document = _createDocument();
    _launchUrlDelegate = DocumentUrlLauncher(this);
  }

  Document _createDocument() {
    final bountyHuntersLinkAttribution = LinkAttribution(url: Uri.parse("https://flutterbountyhunters.com"));

    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(text: "Tappable links"),
          metadata: {"blockType": header1Attribution},
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
              text:
                  "This demo includes links that the user can tap. The user's tap is captured and reported to a delegate. Apps that user SuperReader can implement that delegate to open a browser tab, or take other actions."),
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: "Follow the link to the Flutter Bounty Hunters",
            spans: AttributedSpans(
              attributions: [
                SpanMarker(attribution: bountyHuntersLinkAttribution, offset: 23, markerType: SpanMarkerType.start),
                SpanMarker(attribution: bountyHuntersLinkAttribution, offset: 44, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool launchUri(Uri url) {
    print("Launch URI: $url");
    return true;
  }

  @override
  bool launchUrlString(String url) {
    print("Launch URL: $url");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SuperReader(
      document: _document,
      documentTapDelegate: _launchUrlDelegate,
    );
  }
}
