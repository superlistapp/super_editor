import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class ComputeTextSpanBug extends StatefulWidget {
  @override
  _ComputeTextSpanBugState createState() => _ComputeTextSpanBugState();
}

class _ComputeTextSpanBugState extends State<ComputeTextSpanBug> {
  final TextEditingController _controller = TextEditingController();
  late Document _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor.custom(
      editor: _docEditor,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      textStyleBuilder: _textStyleBuilder,
    );
  }

  TextStyle _textStyleBuilder(Set<Attribution> attributions) {
    var newStyle = defaultStyleBuilder(attributions);

    for (final attribution in attributions) {
      if (attribution == primaryHeaderAttribution) {
        newStyle = newStyle.copyWith(
          color: Colors.blue,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          height: 1.0,
        );
      }
    }

    return newStyle;
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: '',
          spans: AttributedSpans(
            attributions: [
              const SpanMarker(
                attribution: primaryHeaderAttribution,
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: primaryHeaderAttribution,
                offset: 0,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
        ),
      ),
    ],
  );
}

class PrimaryHeaderAttribution extends NamedAttribution {
  const PrimaryHeaderAttribution() : super('NamedAttribution');
}

const primaryHeaderAttribution = NamedAttribution('header2');
