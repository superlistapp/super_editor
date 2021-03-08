import 'core/attributed_spans.dart';
import 'core/attributed_text.dart';
import 'core/document.dart';
import 'core/document_editor.dart';
import 'default_editor/horizontal_rule.dart';
import 'default_editor/image.dart';
import 'default_editor/list_items.dart';
import 'default_editor/paragraph.dart';

Document createEmptyDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: ''),
      ),
    ],
  );
}

Document createStartingPointDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: ''),
        metadata: {
          'blockType': 'header1',
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: ''),
      ),
    ],
  );
}

Document createLoremIpsumDoc() {
  return MutableDocument(nodes: [
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(
        text: _loremIpsum1,
        attributions: [
          SpanMarker(attribution: 'bold', offset: 20, markerType: SpanMarkerType.start),
          SpanMarker(attribution: 'bold', offset: 80, markerType: SpanMarkerType.end),
        ],
      ),
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum2),
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum3),
    ),
  ]);
}

Document createRichContentDoc() {
  return MutableDocument(nodes: [
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'Super Editor'),
      metadata: {
        'blockType': 'header1',
      },
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'Rich text and multimedia'),
      metadata: {
        'blockType': 'header2',
      },
    ),
    ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: _loremIpsum1,
          attributions: [
            SpanMarker(attribution: 'bold', offset: 20, markerType: SpanMarkerType.start),
            SpanMarker(attribution: 'bold', offset: 80, markerType: SpanMarkerType.end),
          ],
        ),
        metadata: {
          'textAlign': 'justify',
        }),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum1),
      metadata: {
        'textAlign': 'center',
      },
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is some important quotation about something.'),
      metadata: {
        'blockType': 'blockquote',
      },
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum1),
      metadata: {
        'textAlign': 'right',
      },
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 1st list item.'),
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 2nd list item.'),
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 3rd list item.'),
      indent: 1,
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 4th list item.'),
      indent: 1,
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 5th list item.'),
    ),
    HorizontalRuleNode(id: DocumentEditor.createNodeId()),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 1st list item.'),
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 2nd list item.'),
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 3rd list item.'),
      indent: 1,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 4th list item.'),
      indent: 1,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 5th list item.'),
      indent: 2,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 6th list item.'),
      indent: 2,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 7th list item.'),
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum2),
    ),
    ImageNode(
      id: DocumentEditor.createNodeId(),
      imageUrl:
          'https://images.unsplash.com/photo-1612099453097-26a809f51e96?ixid=MXwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHw%3D&ixlib=rb-1.2.1&auto=format&fit=crop&w=1050&q=80',
    ),
    ParagraphNode(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: _loremIpsum3),
    ),
  ]);
}

Document createListItemsDoc() {
  return MutableDocument(nodes: [
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 1st list item.'),
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 2nd list item.'),
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 3rd list item.'),
      indent: 1,
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 4th list item.'),
      indent: 1,
    ),
    ListItemNode.unordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 5th list item.'),
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 1st list item.'),
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 2nd list item.'),
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 3rd list item.'),
      indent: 1,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 4th list item.'),
      indent: 1,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 5th list item.'),
      indent: 2,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 6th list item.'),
      indent: 2,
    ),
    ListItemNode.ordered(
      id: DocumentEditor.createNodeId(),
      text: AttributedText(text: 'This is the 7th list item.'),
    ),
  ]);
}

const _loremIpsum1 =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
const _loremIpsum2 =
    'Nullam id elementum felis. Morbi ullamcorper gravida vulputate. Nulla sed gravida lorem. Nam tincidunt, arcu sit amet sodales aliquet, lectus magna volutpat felis, non pharetra risus risus dignissim mauris. Fusce diam massa, semper eu elementum in, dictum vel nulla. Etiam porta luctus augue, porttitor porta nibh. Donec risus arcu, viverra sed tincidunt id, lobortis non nulla. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean vel lobortis quam, ac pulvinar risus. Praesent laoreet tempor ex. Nunc eu ante nisl. Integer in magna ligula.';
const _loremIpsum3 =
    'Phasellus non gravida arcu. Pellentesque posuere orci et lorem fermentum, sed interdum metus vestibulum. Maecenas suscipit mollis sagittis. Mauris quis est blandit libero vehicula fringilla eget in augue. Etiam mi lectus, ullamcorper ac odio nec, maximus ultricies enim. Aenean nec est non nunc tincidunt rhoncus. Proin laoreet vitae libero ut faucibus. Donec bibendum laoreet dolor eu varius. Pellentesque ullamcorper turpis quis viverra semper.';
