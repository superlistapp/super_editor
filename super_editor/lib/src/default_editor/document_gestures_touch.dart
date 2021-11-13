import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';

/// Governs touch gesture interaction with a document, such as dragging
/// to scroll a document, and dragging handles to expand a selection.
///
/// See also: super_editor's mouse gesture support.

/// Document gesture interactor that's designed for touch input, e.g.,
/// drag to scroll, and handles to control selection.
class DocumentTouchInteractor extends StatefulWidget {
  const DocumentTouchInteractor({
    Key? key,
    this.focusNode,
    required this.editContext,
    this.scrollController,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;
  final EditContext editContext;
  final ScrollController? scrollController;
  final bool showDebugPaint;
  final Widget child;

  @override
  _DocumentTouchInteractorState createState() => _DocumentTouchInteractorState();
}

class _DocumentTouchInteractorState extends State<DocumentTouchInteractor> {
  @override
  Widget build(BuildContext context) {
    return ErrorWidget("DocumentTouchInteractor is not yet implemented!");
  }
}
