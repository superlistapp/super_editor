import 'package:flutter/widgets.dart';

/// Builder that returns a widget that handles desired gestures, instead of
/// letting [SuperTextField] respond to those gestures.
///
/// The given [textFieldKey] can be used to access the [RenderBox] and the
/// [ProseTextLayout] for the [SuperTextField]:
///
/// ```
/// final renderBox = textFieldKey.currentContext.findRenderObject as RenderBox;
/// final textLayout = (textFieldKey.currentState as ProseTextBlock).textLayout;
/// ```
///
/// The given [child] represents everything in [SuperTextField] beneath the gesture
/// system. If [child] is non-null, the return [Widget] **must** include that [child]
/// in its sub-tree.
typedef GestureOverrideBuilder = Widget Function(BuildContext, GlobalKey textFieldKey, [Widget? child]);
