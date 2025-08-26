import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(
    MaterialApp(
      home: _ComponentsInComponentsDemoScreen(),
    ),
  );
}

class _ComponentsInComponentsDemoScreen extends StatefulWidget {
  const _ComponentsInComponentsDemoScreen({super.key});

  @override
  State<_ComponentsInComponentsDemoScreen> createState() => _ComponentsInComponentsDemoScreenState();
}

class _ComponentsInComponentsDemoScreenState extends State<_ComponentsInComponentsDemoScreen> {
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument(
        nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText("This is a demo of a Banner component."),
            metadata: {
              NodeMetadata.blockType: header1Attribution,
            },
          ),
          _BannerNode(id: "2", children: [
            ParagraphNode(
              id: "3",
              text: AttributedText("Hello, Banner!"),
              metadata: {
                NodeMetadata.blockType: header1Attribution,
              },
            ),
            ParagraphNode(
              id: "4",
              text: AttributedText("This is a banner, which can contain any other blocks you want"),
            ),
          ]),
          ParagraphNode(
            id: "5",
            text: AttributedText("This is after the banner component."),
          ),
        ],
      ),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(
        editor: _editor,
        componentBuilders: [
          _BannerComponentBuilder(),
          ...defaultComponentBuilders,
        ],
      ),
    );
  }
}

class _BannerNode extends DocumentNode {
  _BannerNode({
    required this.id,
    required this.children,
  });

  @override
  final String id;

  final List<DocumentNode> children;

  @override
  NodePosition get beginningPosition => CompositeNodePosition(
        children.first.id,
        children.first.beginningPosition,
      );

  @override
  NodePosition get endPosition => CompositeNodePosition(
        children.last.id,
        children.last.endPosition,
      );

  @override
  bool containsPosition(Object position) {
    if (position is! CompositeNodePosition) {
      return false;
    }

    for (final child in children) {
      if (child.id == position.childNodeId) {
        return child.containsPosition(position.childNodePosition);
      }
    }

    return false;
  }

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! CompositeNodePosition) {
      throw Exception('Expected a _CompositeNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! CompositeNodePosition) {
      throw Exception('Expected a _CompositeNodePosition for position2 but received a ${position2.runtimeType}');
    }

    final index1 = int.parse(position1.childNodeId);
    final index2 = int.parse(position2.childNodeId);

    if (index1 == index2) {
      return position1.childNodePosition ==
              children[index1].selectUpstreamPosition(position1.childNodePosition, position2.childNodePosition)
          ? position1
          : position2;
    }

    return index1 < index2 ? position1 : position2;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    final upstream = selectUpstreamPosition(position1, position2);
    return upstream == position1 ? position2 : position1;
  }

  @override
  NodeSelection computeSelection({required NodePosition base, required NodePosition extent}) {
    assert(base is CompositeNodePosition);
    assert(extent is CompositeNodePosition);

    return BannerNodeSelection(
      base: base as CompositeNodePosition,
      extent: extent as CompositeNodePosition,
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    // TODO: implement copyWithAddedMetadata
    throw UnimplementedError();
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    // TODO: implement copyAndReplaceMetadata
    throw UnimplementedError();
  }

  @override
  String? copyContent(NodeSelection selection) {
    // TODO: implement copyContent
    throw UnimplementedError();
  }
}

class BannerNodeSelection implements NodeSelection {
  const BannerNodeSelection.collapsed(CompositeNodePosition position)
      : base = position,
        extent = position;

  const BannerNodeSelection({
    required this.base,
    required this.extent,
  });

  final CompositeNodePosition base;

  final CompositeNodePosition extent;
}

class _BannerComponentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    PresenterContext presenterContext,
    Document document,
    DocumentNode node,
  ) {
    if (node is! _BannerNode) {
      return null;
    }

    return _BannerViewModel(
      nodeId: node.id,
      children: node.children.map((childNode) => presenterContext.createViewModel(childNode)!).toList(),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! _BannerViewModel) {
      return null;
    }

    final childrenAndKeys = componentViewModel.children
        .map(
          (childViewModel) => componentContext.buildChildComponent(childViewModel),
        )
        .toList(growable: false);

    print("Building a _BannerComponent - banner key: ${componentContext.componentKey}");
    print(" - child keys: ${childrenAndKeys.map((x) => x.$1)}");
    return _BannerComponent(
      key: componentContext.componentKey,
      // childComponentIds: [],
      childComponentKeys: childrenAndKeys.map((childAndKey) => childAndKey.$1).toList(growable: false),
      children: [
        for (final child in childrenAndKeys) //
          child.$2,
      ],
    );
  }
}

class _BannerViewModel extends SingleColumnLayoutComponentViewModel {
  _BannerViewModel({
    required super.nodeId,
    super.createdAt,
    super.padding = EdgeInsets.zero,
    super.maxWidth,
    required this.children,
  });

  final List<SingleColumnLayoutComponentViewModel> children;

  @override
  SingleColumnLayoutComponentViewModel copy() {
    return _BannerViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      padding: padding,
      maxWidth: maxWidth,
      children: List.from(children),
    );
  }
}

class _BannerComponent extends StatefulWidget {
  const _BannerComponent({
    super.key,
    // required this.childComponentIds,
    required this.childComponentKeys,
    required this.children,
  });

  // final List<String> childComponentIds;

  final List<GlobalKey<DocumentComponent>> childComponentKeys;

  final List<Widget> children;

  @override
  State<_BannerComponent> createState() => _BannerComponentState();
}

class _BannerComponentState extends State<_BannerComponent> with ProxyDocumentComponent<_BannerComponent> {
  @override
  final childDocumentComponentKey = GlobalKey(debugLabel: 'banner-internal-column');

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ColumnDocumentComponent(
          key: childDocumentComponentKey,
          // childComponentIds: widget.childComponentIds,
          childComponentKeys: widget.childComponentKeys,
          children: widget.children,
        ),
      ),
    );
  }
}
