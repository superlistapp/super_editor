import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '_doc_components.dart';
import '_doc_model.dart';
import '_selection.dart';

/// Spike:
/// Can we use `EditableText` widgets as the basis for displaying
/// and editing a very simple document?
///
/// This spike implements:
///  - Display of a basic document format, consisting of a list of
///    content fragments, e.g., title, paragraph, list item, image.
///  - Mouse scrolling. Drag scroll disabled.
///  - Text selection across `EditableText` widgets within the
///    document, including while scrolling.
///
/// Failure points:
///  - I don't think EditableText can be composed in an editor. EditableText
///    implements direct handling of a text input connection from the underlying
///    platform. EditableText owns the corresponding TextEditingValue, which means
///    we can't take over ownership. Additionally, RenderEditable also listens
///    for raw keyboard presses and takes specific, internal actions based on
///    the keys pressed. I think we need the editor itself to implement a
///    text input client and then forward appropriate information to the selected
///    document component.
///
/// Anti-Goals:
///  - editor commands/toolbars
///
/// Rough Behaviors:
/// This spike re-implements some fundamental behaviors, like scrolling,
/// so that we gain the control necessary to work with drag selection.
/// These implementations are very rough. We should try to find ways to
/// use more of the built-in constructs so that we only re-engineer the
/// minimum set of capabilities. If we can't re-use existing solutions
/// then we at least need to implement a much more robust version of
/// these behaviors.

final exampleDoc = Document(
  content: [
    DocumentTitle(
      text: 'This is the title',
    ),
    DocumentParagraph(
      text:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
    ),
    DocumentListItem(
      text: 'This is a list item',
    ),
    DocumentListItem(
      text: 'This is a list item',
    ),
    DocumentListItem(
      text: 'This is a list item',
    ),
    DocumentParagraph(
      text:
          'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?',
    ),
    DocumentHorizontalRule(),
    DocumentImage(
      imageProvider: NetworkImage(
        'https://www.lifewire.com/thmb/oHOjLWKEc9cIAVjsgT5Vka3axFE=/923x647/filters:fill(auto,1)/sublime2-56a5aa575f9b58b7d0dde2ba.jpg',
      ),
    ),
    DocumentHorizontalRule(),
    DocumentParagraph(
      text:
          'At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio. Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis doloribus asperiores repellat.',
    ),
  ],
);

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: DocModelAndDisplaySpike(
          doc: exampleDoc,
        ),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class DocModelAndDisplaySpike extends StatefulWidget {
  const DocModelAndDisplaySpike({Key key, this.doc}) : super(key: key);

  final Document doc;

  @override
  _DocModelAndDisplaySpikeState createState() => _DocModelAndDisplaySpikeState();
}

class _DocModelAndDisplaySpikeState extends State<DocModelAndDisplaySpike> with SingleTickerProviderStateMixin {
  final _componentSpacer = SizedBox(height: 16);

  final _docContentToKey = <DocumentContent, GlobalKey>{};

  Ticker _ticker;

  ScrollController _scrollController;
  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;

  Offset _dragStartPosition;
  double _dragStartScrollOffset;
  Offset _currentDragPosition;
  Rect _dragRect;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTap() {
    print('tap');
    _clearContentSelection();
  }

  void _onPanStart(DragStartDetails details) {
    _dragStartPosition = details.localPosition;
    _dragStartScrollOffset = _scrollController.offset;

    _clearContentSelection();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _currentDragPosition = details.localPosition;

    _scrollIfNearBoundary();

    _updateDragRect();
  }

  void _scrollIfNearBoundary() {
    final editorBox = context.findRenderObject() as RenderBox;

    if (_currentDragPosition.dy < 50) {
      _startScrollingUp();
    } else {
      _stopScrollingUp();
    }
    if (editorBox.size.height - _currentDragPosition.dy < 50) {
      _startScrollingDown();
    } else {
      _stopScrollingDown();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _stopScrollingUp();
    _stopScrollingDown();
    _clearDragSelectionOutlines();

    setState(() {
      _dragStartPosition = null;
      _currentDragPosition = null;
      _dragRect = null;
    });
  }

  void _onPanCancel() {
    _stopScrollingUp();
    _stopScrollingDown();
    _clearDragSelectionOutlines();

    setState(() {
      _dragRect = null;
    });
  }

  /// We prevent SingleChildScrollView from processing mouse events because
  /// it scrolls by drag by default, which we don't want. However, we do
  /// still want mouse scrolling. This method re-implements a primitive
  /// form of mouse scrolling.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final newScrollOffset =
          (_scrollController.offset + event.scrollDelta.dy).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newScrollOffset);

      _updateDragRect();
    }
  }

  void _startScrollingUp() {
    if (_scrollUpOnTick) {
      return;
    }

    _scrollUpOnTick = true;
    _ticker.start();
  }

  void _stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    _scrollUpOnTick = false;
    _ticker.stop();
  }

  void _scrollUp() {
    _scrollController.position.jumpTo(_scrollController.offset - 2);
  }

  void _startScrollingDown() {
    if (_scrollDownOnTick) {
      return;
    }

    _scrollDownOnTick = true;
    _ticker.start();
  }

  void _stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    _scrollDownOnTick = false;
    _ticker.stop();
  }

  void _scrollDown() {
    _scrollController.position.jumpTo(_scrollController.offset + 2);
  }

  void _onTick(elapsedTime) {
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
    _updateDragRect();
  }

  void _updateDragRect() {
    if (_dragStartPosition == null || _currentDragPosition == null) {
      return;
    }

    setState(() {
      _dragRect = Rect.fromPoints(
          _dragStartPosition + Offset(0, _dragStartScrollOffset) - Offset(0, _scrollController.offset),
          _currentDragPosition);

      _applySelection();
    });
  }

  void _applySelection() {
    if (_dragRect == null) {
      _clearDragSelectionOutlines();
      return;
    }

    final editorRenderbox = context.findRenderObject() as RenderBox;

    print('Applying selection to content.');
    print(' - Drag rect: $_dragRect}');
    for (final contentKey in _docContentToKey.values) {
      if (contentKey.currentContext == null) {
        print('A content component has no context. Widget: ${contentKey.currentWidget}');
        continue;
      }

      final contentComponent = contentKey.currentState as EditorComponent;
      if (contentComponent == null) {
        print('A content component does not implement EditorComponent: ${contentKey.currentState}');
        continue;
      }

      final contentRenderBox = contentKey.currentContext.findRenderObject() as RenderBox;
      final contentBounds =
          contentRenderBox.localToGlobal(Offset.zero, ancestor: editorRenderbox) & contentRenderBox.size;
      // print(' - Content bounds: $contentBounds');

      if (_dragRect.overlaps(contentBounds)) {
        print(' - Drag intersects: $contentRenderBox');
        contentComponent.onDragSelectionChange(
          dragBounds: _dragRect,
          renderEditor: editorRenderbox,
        );
      } else {
        contentComponent
          ..onDragSelectionEnd()
          ..clearContentSelection();
      }
    }
  }

  void _clearDragSelectionOutlines() {
    for (final contentKey in _docContentToKey.values) {
      final contentComponent = contentKey.currentState as EditorComponent;
      if (contentComponent == null) {
        print('A content component does not implement EditorComponent: ${contentKey.currentState}');
        continue;
      }
      contentComponent.onDragSelectionEnd();
    }
  }

  void _clearContentSelection() {
    for (final contentKey in _docContentToKey.values) {
      final contentComponent = contentKey.currentState as EditorComponent;
      if (contentComponent == null) {
        print('A content component does not implement EditorComponent: ${contentKey.currentState}');
        continue;
      }
      contentComponent.clearContentSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onTap: _onTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 128.0, vertical: 48),
                child: Column(
                  children: _buildEditorComponents(),
                ),
              ),
            ),
            CustomPaint(
              painter: DragRectanglePainter(
                selectionRect: _dragRect ?? Rect.zero,
              ),
              size: Size.infinite,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEditorComponents() {
    final components = <Widget>[];
    if (widget.doc != null) {
      for (final content in widget.doc.content) {
        components.addAll([
          _buildEditorComponent(content),
          _componentSpacer,
        ]);
      }
    }
    return components;
  }

  Widget _buildEditorComponent(DocumentContent content) {
    final contentKey = _docContentToKey[content] ?? GlobalKey();
    if (_docContentToKey[content] == null) {
      _docContentToKey[content] = contentKey;
    }

    if (content is DocumentTitle) {
      return EditorTitleComponent(
        key: contentKey,
        title: content,
      );
    } else if (content is DocumentParagraph) {
      return EditorParagraphComponent(
        key: contentKey,
        paragraph: content,
      );
    } else if (content is DocumentListItem) {
      return EditorListItemComponent(
        key: contentKey,
        listItem: content,
      );
    } else if (content is DocumentImage) {
      return Center(
        child: Image(
          image: content.imageProvider,
          fit: BoxFit.contain,
        ),
      );
    } else if (content is DocumentHorizontalRule) {
      return EditorHorizontalRuleComponent(
        key: contentKey,
      );
    } else {
      return Text('404: Unknown content type: $content');
    }
  }
}
