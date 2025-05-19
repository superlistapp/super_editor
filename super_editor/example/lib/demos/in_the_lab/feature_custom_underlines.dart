import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class CustomUnderlinesDemo extends StatefulWidget {
  const CustomUnderlinesDemo({super.key});

  @override
  State<CustomUnderlinesDemo> createState() => _CustomUnderlinesDemoState();
}

class _CustomUnderlinesDemoState extends State<CustomUnderlinesDemo> {
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: _createDocument(),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: SuperEditor(
        editor: _editor,
        stylesheet: defaultStylesheet.copyWith(
          addRulesBefore: [
            StyleRule(
              BlockSelector.all,
              (doc, docNode) {
                return {
                  Styles.customUnderlineStyles: CustomUnderlineStyles({
                    _brandUnderline: StraightUnderlineStyle(
                      color: Colors.red,
                      thickness: 3,
                      capType: StrokeCap.round,
                      offset: -3,
                    ),
                    _dottedUnderline: DottedUnderlineStyle(
                      color: Colors.blue,
                    ),
                    _squiggleUnderline: SquiggleUnderlineStyle(
                      color: Colors.green,
                    ),
                  }),
                };
              },
            ),
          ],
          addRulesAfter: [
            ...darkModeStyles,
          ],
          selectedTextColorStrategy: ({
            required Color originalTextColor,
            required Color selectionHighlightColor,
          }) =>
              Colors.black,
        ),
        documentOverlayBuilders: [
          DefaultCaretOverlayBuilder(
            caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

MutableDocument _createDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText("Custom Underlines"),
        metadata: {
          NodeMetadata.blockType: header1Attribution,
        },
      ),
      ParagraphNode(
        id: "2",
        text: AttributedText(
          "Super Editor supports custom painted underlines across text spans.",
          AttributedSpans(
            attributions: [
              SpanMarker(
                attribution: CustomUnderlineAttribution(_brandUnderline),
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: CustomUnderlineAttribution(_brandUnderline),
                offset: 11,
                markerType: SpanMarkerType.end,
              ),
              SpanMarker(
                attribution: CustomUnderlineAttribution(_dottedUnderline),
                offset: 22,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: CustomUnderlineAttribution(_dottedUnderline),
                offset: 35,
                markerType: SpanMarkerType.end,
              ),
              SpanMarker(
                attribution: CustomUnderlineAttribution(_squiggleUnderline),
                offset: 48,
                markerType: SpanMarkerType.start,
              ),
              SpanMarker(
                attribution: CustomUnderlineAttribution(_squiggleUnderline),
                offset: 64,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

const _brandUnderline = "brand";
const _dottedUnderline = "dotted";
const _squiggleUnderline = "squiggly";
