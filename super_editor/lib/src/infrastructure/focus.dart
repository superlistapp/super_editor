import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Widget that responds to keyboard events for a given [focusNode] without
/// necessarily re-parenting the [focusNode].
///
/// The [focusNode] is only re-parented if its parent is `null`.
///
/// The traditional [Focus] widget provides an `onKey` property, but that widget
/// automatically re-parents the [FocusNode] based on the structure of the widget
/// tree. Re-parenting is a problem in some situations, e.g., a popover toolbar
/// that appears while editing a document. The toolbar and the document are on
/// different branches of the widget tree, but they need to share focus. That shared
/// focus is impossible when the [Focus] widget forces re-parenting. The
/// [NonReparentingFocus] widget provides an [onKey] property without re-parenting the
/// given [focusNode].
class NonReparentingFocus extends StatefulWidget {
  const NonReparentingFocus({
    Key? key,
    required this.focusNode,
    this.onKeyEvent,
    required this.child,
  }) : super(key: key);

  /// The [FocusNode] that sends key events to [onKey].
  final FocusNode focusNode;


  /// The callback invoked whenever [focusNode] receives [KeyEvent] events.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// The child of this widget.
  final Widget child;

  @override
  State<NonReparentingFocus> createState() => _NonReparentingFocusState();
}

class _NonReparentingFocusState extends State<NonReparentingFocus> {
  late FocusAttachment _keyboardFocusAttachment;

  @override
  void initState() {
    super.initState();
    _keyboardFocusAttachment = widget.focusNode.attach(context, onKeyEvent: _onKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reparentIfMissingParent();
  }

  @override
  void didUpdateWidget(NonReparentingFocus oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _keyboardFocusAttachment.detach();
      _keyboardFocusAttachment = widget.focusNode.attach(context, onKeyEvent: _onKeyEvent);
      _reparentIfMissingParent();
    }
  }

  @override
  void dispose() {
    _keyboardFocusAttachment.detach();
    super.dispose();
  }

  void _reparentIfMissingParent() {
    if (widget.focusNode.parent == null) {
      _keyboardFocusAttachment.reparent();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent event) {
    return widget.onKeyEvent?.call(focusNode, event) ?? KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _reparentIfMissingParent();

    return widget.child;
  }
}

/// Copy of [Focus] that configures its [FocusNode] with the
/// given [parentNode], rather than automatically re-parenting based
/// on the widget tree structure.
///
/// One reason to attach a [FocusNode] to a parent [FocusNode] that
/// isn't an ancestor in the widget tree is an editor with a popover
/// toolbar that contains a text field for entering a link URL. With
/// this widget, the editor's [FocusNode] can become the parent of the
/// toolbar's [FocusNode], which allows the editor to remain "focused"
/// while the user types a URL into the toolbar's text field, which has
/// "primary focus".
///
/// The only changes made to [Focus] are the parts related to re-parenting.
/// As a result, there may be [Focus] behaviors that don't work. We don't
/// want to invest the time to re-write all the standard [Focus] tests.
/// Hopefully, Flutter #106923 will result in changes to [Focus] that make
/// [FocusWithCustomParent] superfluous, and we can remove it.
class FocusWithCustomParent extends StatefulWidget {
  const FocusWithCustomParent({
    Key? key,
    this.focusNode,
    this.parentFocusNode,
    this.autofocus = false,
    this.onFocusChange,
    FocusOnKeyEventCallback? onKeyEvent,
    FocusOnKeyCallback? onKey,
    bool? canRequestFocus,
    bool? skipTraversal,
    bool? descendantsAreFocusable,
    bool? descendantsAreTraversable,
    this.includeSemantics = true,
    String? debugLabel,
    required this.child,
  })  : _onKeyEvent = onKeyEvent,
        _onKey = onKey,
        _canRequestFocus = canRequestFocus,
        _skipTraversal = skipTraversal,
        _descendantsAreFocusable = descendantsAreFocusable,
        _descendantsAreTraversable = descendantsAreTraversable,
        _debugLabel = debugLabel,
        super(key: key);

  // Indicates whether the widget's focusNode attributes should have priority
  // when then widget is updated.
  bool get _usingExternalFocus => false;

  /// The child widget of this [FocusWithCustomParent].
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// {@template flutter.widgets.Focus.focusNode}
  /// An optional focus node to use as the focus node for this widget.
  ///
  /// If one is not supplied, then one will be automatically allocated, owned,
  /// and managed by this widget. The widget will be focusable even if a
  /// [focusNode] is not supplied. If supplied, the given `focusNode` will be
  /// _hosted_ by this widget, but not owned. See [FocusNode] for more
  /// information on what being hosted and/or owned implies.
  ///
  /// Supplying a focus node is sometimes useful if an ancestor to this widget
  /// wants to control when this widget has the focus. The owner will be
  /// responsible for calling [FocusNode.dispose] on the focus node when it is
  /// done with it, but this widget will attach/detach and reparent the node
  /// when needed.
  /// {@endtemplate}
  ///
  /// A non-null [focusNode] must be supplied if using the
  /// [Focus.withExternalFocusNode] constructor is used.
  final FocusNode? focusNode;

  /// The [FocusNode] that's installed as the parent of [focusNode], regardless
  /// of the location of [parentFocusNode] in the widget tree.
  final FocusNode? parentFocusNode;

  /// {@template flutter.widgets.Focus.autofocus}
  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  ///
  /// Ideally, there is only one widget with autofocus set in each [FocusScope].
  /// If there is more than one widget with autofocus set, then the first one
  /// added to the tree will get focus.
  ///
  /// Must not be null. Defaults to false.
  /// {@endtemplate}
  final bool autofocus;

  /// Handler called when the focus changes.
  ///
  /// Called with true if this widget's node gains focus, and false if it loses
  /// focus.
  final ValueChanged<bool>? onFocusChange;

  /// A handler for keys that are pressed when this object or one of its
  /// children has focus.
  ///
  /// Key events are first given to the [FocusNode] that has primary focus, and
  /// if its [onKeyEvent] method returns [KeyEventResult.ignored], then they are
  /// given to each ancestor node up the focus hierarchy in turn. If an event
  /// reaches the root of the hierarchy, it is discarded.
  ///
  /// This is not the way to get text input in the manner of a text field: it
  /// leaves out support for input method editors, and doesn't support soft
  /// keyboards in general. For text input, consider [TextField],
  /// [EditableText], or [CupertinoTextField] instead, which do support these
  /// things.
  FocusOnKeyEventCallback? get onKeyEvent => _onKeyEvent ?? focusNode?.onKeyEvent;
  final FocusOnKeyEventCallback? _onKeyEvent;

  /// A handler for keys that are pressed when this object or one of its
  /// children has focus.
  ///
  /// This is a legacy API based on [RawKeyEvent] and will be deprecated in the
  /// future. Prefer [onKeyEvent] instead.
  ///
  /// Key events are first given to the [FocusNode] that has primary focus, and
  /// if its [onKey] method return false, then they are given to each ancestor
  /// node up the focus hierarchy in turn. If an event reaches the root of the
  /// hierarchy, it is discarded.
  ///
  /// This is not the way to get text input in the manner of a text field: it
  /// leaves out support for input method editors, and doesn't support soft
  /// keyboards in general. For text input, consider [TextField],
  /// [EditableText], or [CupertinoTextField] instead, which do support these
  /// things.
  FocusOnKeyCallback? get onKey => _onKey ?? focusNode?.onKey;
  final FocusOnKeyCallback? _onKey;

  /// {@template flutter.widgets.Focus.canRequestFocus}
  /// If true, this widget may request the primary focus.
  ///
  /// Defaults to true.  Set to false if you want the [FocusNode] this widget
  /// manages to do nothing when [FocusNode.requestFocus] is called on it. Does
  /// not affect the children of this node, and [FocusNode.hasFocus] can still
  /// return true if this node is the ancestor of the primary focus.
  ///
  /// This is different than [FocusWithCustomParent.skipTraversal] because [FocusWithCustomParent.skipTraversal]
  /// still allows the widget to be focused, just not traversed to.
  ///
  /// Setting [FocusNode.canRequestFocus] to false implies that the widget will
  /// also be skipped for traversal purposes.
  ///
  /// See also:
  ///
  /// * [FocusTraversalGroup], a widget that sets the traversal policy for its
  ///   descendants.
  /// * [FocusTraversalPolicy], a class that can be extended to describe a
  ///   traversal policy.
  /// {@endtemplate}
  bool get canRequestFocus => _canRequestFocus ?? focusNode?.canRequestFocus ?? true;
  final bool? _canRequestFocus;

  /// Sets the [FocusNode.skipTraversal] flag on the focus node so that it won't
  /// be visited by the [FocusTraversalPolicy].
  ///
  /// This is sometimes useful if a [FocusWithCustomParent] widget should receive key events as
  /// part of the focus chain, but shouldn't be accessible via focus traversal.
  ///
  /// This is different from [FocusNode.canRequestFocus] because it only implies
  /// that the widget can't be reached via traversal, not that it can't be
  /// focused. It may still be focused explicitly.
  bool get skipTraversal => _skipTraversal ?? focusNode?.skipTraversal ?? false;
  final bool? _skipTraversal;

  /// {@template flutter.widgets.Focus.descendantsAreFocusable}
  /// If false, will make this widget's descendants unfocusable.
  ///
  /// Defaults to true. Does not affect focusability of this node (just its
  /// descendants): for that, use [FocusNode.canRequestFocus].
  ///
  /// If any descendants are focused when this is set to false, they will be
  /// unfocused. When `descendantsAreFocusable` is set to true again, they will
  /// not be refocused, although they will be able to accept focus again.
  ///
  /// Does not affect the value of [FocusNode.canRequestFocus] on the
  /// descendants.
  ///
  /// If a descendant node loses focus when this value is changed, the focus
  /// will move to the scope enclosing this node.
  ///
  /// See also:
  ///
  /// * [ExcludeFocus], a widget that uses this property to conditionally
  ///   exclude focus for a subtree.
  /// * [descendantsAreTraversable], which makes this widget's descendants
  ///   untraversable.
  /// * [ExcludeFocusTraversal], a widget that conditionally excludes focus
  ///   traversal for a subtree.
  /// * [FocusTraversalGroup], a widget used to group together and configure the
  ///   focus traversal policy for a widget subtree that has a
  ///   `descendantsAreFocusable` parameter to conditionally block focus for a
  ///   subtree.
  /// {@endtemplate}
  bool get descendantsAreFocusable => _descendantsAreFocusable ?? focusNode?.descendantsAreFocusable ?? true;
  final bool? _descendantsAreFocusable;

  /// {@template flutter.widgets.Focus.descendantsAreTraversable}
  /// If false, will make this widget's descendants untraversable.
  ///
  /// Defaults to true. Does not affect traversablility of this node (just its
  /// descendants): for that, use [FocusNode.skipTraversal].
  ///
  /// Does not affect the value of [FocusNode.skipTraversal] on the
  /// descendants. Does not affect focusability of the descendants.
  ///
  /// See also:
  ///
  /// * [ExcludeFocusTraversal], a widget that uses this property to
  ///   conditionally exclude focus traversal for a subtree.
  /// * [descendantsAreFocusable], which makes this widget's descendants
  ///   unfocusable.
  /// * [ExcludeFocus], a widget that conditionally excludes focus for a subtree.
  /// * [FocusTraversalGroup], a widget used to group together and configure the
  ///   focus traversal policy for a widget subtree that has a
  ///   `descendantsAreFocusable` parameter to conditionally block focus for a
  ///   subtree.
  /// {@endtemplate}
  bool get descendantsAreTraversable => _descendantsAreTraversable ?? focusNode?.descendantsAreTraversable ?? true;
  final bool? _descendantsAreTraversable;

  /// {@template flutter.widgets.Focus.includeSemantics}
  /// Include semantics information in this widget.
  ///
  /// If true, this widget will include a [Semantics] node that indicates the
  /// [SemanticsProperties.focusable] and [SemanticsProperties.focused]
  /// properties.
  ///
  /// It is not typical to set this to false, as that can affect the semantics
  /// information available to accessibility systems.
  ///
  /// Must not be null, defaults to true.
  /// {@endtemplate}
  final bool includeSemantics;

  /// A debug label for this widget.
  ///
  /// Not used for anything except to be printed in the diagnostic output from
  /// [toString] or [toStringDeep].
  ///
  /// To get a string with the entire tree, call [debugDescribeFocusTree]. To
  /// print it to the console call [debugDumpFocusTree].
  ///
  /// Defaults to null.
  String? get debugLabel => _debugLabel ?? focusNode?.debugLabel;
  final String? _debugLabel;

  /// Returns the [focusNode] of the [FocusWithCustomParent] that most tightly encloses the
  /// given [BuildContext].
  ///
  /// If no [FocusWithCustomParent] node is found before reaching the nearest [FocusScope]
  /// widget, or there is no [FocusWithCustomParent] widget in scope, then this method will
  /// throw an exception.
  ///
  /// The `context` and `scopeOk` arguments must not be null.
  ///
  /// Calling this function creates a dependency that will rebuild the given
  /// context when the focus changes.
  ///
  /// See also:
  ///
  ///  * [maybeOf], which is similar to this function, but will return null
  ///    instead of throwing if it doesn't find a [Focus] node.
  static FocusNode of(BuildContext context, {bool scopeOk = false}) {
    final _FocusMarker? marker = context.dependOnInheritedWidgetOfExactType<_FocusMarker>();
    final FocusNode? node = marker?.notifier;
    assert(() {
      if (node == null) {
        throw FlutterError(
          'Focus.of() was called with a context that does not contain a Focus widget.\n'
          'No Focus widget ancestor could be found starting from the context that was passed to '
          'Focus.of(). This can happen because you are using a widget that looks for a Focus '
          'ancestor, and do not have a Focus widget descendant in the nearest FocusScope.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    assert(() {
      if (!scopeOk && node is FocusScopeNode) {
        throw FlutterError(
          'Focus.of() was called with a context that does not contain a Focus between the given '
          'context and the nearest FocusScope widget.\n'
          'No Focus ancestor could be found starting from the context that was passed to '
          'Focus.of() to the point where it found the nearest FocusScope widget. This can happen '
          'because you are using a widget that looks for a Focus ancestor, and do not have a '
          'Focus widget ancestor in the current FocusScope.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return node!;
  }

  /// Returns the [focusNode] of the [FocusWithCustomParent] that most tightly encloses the
  /// given [BuildContext].
  ///
  /// If no [FocusWithCustomParent] node is found before reaching the nearest [FocusScope]
  /// widget, or there is no [FocusWithCustomParent] widget in scope, then this method will
  /// return null.
  ///
  /// The `context` and `scopeOk` arguments must not be null.
  ///
  /// Calling this function creates a dependency that will rebuild the given
  /// context when the focus changes.
  ///
  /// See also:
  ///
  ///  * [of], which is similar to this function, but will throw an exception if
  ///    it doesn't find a [Focus] node instead of returning null.
  static FocusNode? maybeOf(BuildContext context, {bool scopeOk = false}) {
    final _FocusMarker? marker = context.dependOnInheritedWidgetOfExactType<_FocusMarker>();
    final FocusNode? node = marker?.notifier;
    if (node == null) {
      return null;
    }
    if (!scopeOk && node is FocusScopeNode) {
      return null;
    }
    return node;
  }

  /// Returns true if the nearest enclosing [FocusWithCustomParent] widget's node is focused.
  ///
  /// A convenience method to allow build methods to write:
  /// `Focus.isAt(context)` to get whether or not the nearest [FocusWithCustomParent] above them
  /// in the widget hierarchy currently has the input focus.
  ///
  /// Returns false if no [FocusWithCustomParent] widget is found before reaching the nearest
  /// [FocusScope], or if the root of the focus tree is reached without finding
  /// a [FocusWithCustomParent] widget.
  ///
  /// Calling this function creates a dependency that will rebuild the given
  /// context when the focus changes.
  static bool isAt(BuildContext context) => FocusWithCustomParent.maybeOf(context)?.hasFocus ?? false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('debugLabel', debugLabel, defaultValue: null));
    properties.add(FlagProperty('autofocus', value: autofocus, ifTrue: 'AUTOFOCUS', defaultValue: false));
    properties
        .add(FlagProperty('canRequestFocus', value: canRequestFocus, ifFalse: 'NOT FOCUSABLE', defaultValue: false));
    properties.add(FlagProperty('descendantsAreFocusable',
        value: descendantsAreFocusable, ifFalse: 'DESCENDANTS UNFOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('descendantsAreTraversable',
        value: descendantsAreTraversable, ifFalse: 'DESCENDANTS UNTRAVERSABLE', defaultValue: true));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
  }

  @override
  State<FocusWithCustomParent> createState() => _FocusWithCustomParentState();
}

class _FocusWithCustomParentState extends State<FocusWithCustomParent> {
  FocusNode? _internalNode;
  FocusNode get focusNode => widget.focusNode ?? _internalNode!;
  late bool _hadPrimaryFocus;
  late bool _couldRequestFocus;
  late bool _descendantsWereFocusable;
  late bool _descendantsWereTraversable;
  bool _didAutofocus = false;
  late FocusAttachment _focusAttachment;

  @override
  void initState() {
    super.initState();
    _initNode();
  }

  void _initNode() {
    if (widget.focusNode == null) {
      // Only create a new node if the widget doesn't have one.
      // This calls a function instead of just allocating in place because
      // _createNode is overridden in _FocusScopeState.
      _internalNode ??= _createNode();
    }
    focusNode.descendantsAreFocusable = widget.descendantsAreFocusable;
    focusNode.descendantsAreTraversable = widget.descendantsAreTraversable;
    focusNode.skipTraversal = widget.skipTraversal;

    if (widget._canRequestFocus != null) {
      focusNode.canRequestFocus = widget._canRequestFocus!;
    }
    _couldRequestFocus = focusNode.canRequestFocus;
    _descendantsWereFocusable = focusNode.descendantsAreFocusable;
    _descendantsWereTraversable = focusNode.descendantsAreTraversable;
    _hadPrimaryFocus = focusNode.hasPrimaryFocus;
    _focusAttachment = focusNode.attach(context, onKeyEvent: widget.onKeyEvent, onKey: widget.onKey)
      ..reparent(parent: widget.parentFocusNode);

    // Add listener even if the _internalNode existed before, since it should
    // not be listening now if we're re-using a previous one because it should
    // have already removed its listener.
    focusNode.addListener(_handleFocusChanged);
  }

  FocusNode _createNode() {
    return FocusNode(
      debugLabel: widget.debugLabel,
      canRequestFocus: widget.canRequestFocus,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      skipTraversal: widget.skipTraversal,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusAttachment.reparent(parent: widget.parentFocusNode);
    _handleAutofocus();
  }

  @override
  void didUpdateWidget(FocusWithCustomParent oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(() {
      // Only update the debug label in debug builds.
      if (oldWidget.focusNode == widget.focusNode &&
          !widget._usingExternalFocus &&
          oldWidget.debugLabel != widget.debugLabel) {
        focusNode.debugLabel = widget.debugLabel;
      }
      return true;
    }());

    if (oldWidget.focusNode == widget.focusNode) {
      if (!widget._usingExternalFocus) {
        if (widget.onKey != focusNode.onKey) {
          focusNode.onKey = widget.onKey;
        }
        if (widget.onKeyEvent != focusNode.onKeyEvent) {
          focusNode.onKeyEvent = widget.onKeyEvent;
        }

        focusNode.skipTraversal = widget.skipTraversal;

        if (widget._canRequestFocus != null) {
          focusNode.canRequestFocus = widget._canRequestFocus!;
        }
        focusNode.descendantsAreFocusable = widget.descendantsAreFocusable;
        focusNode.descendantsAreTraversable = widget.descendantsAreTraversable;
      }
    } else {
      _focusAttachment.detach();
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      _initNode();
    }

    if (widget.parentFocusNode != oldWidget.parentFocusNode) {
      _focusAttachment.reparent(parent: widget.parentFocusNode);
    }

    if (oldWidget.autofocus != widget.autofocus) {
      _handleAutofocus();
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    // The focus node's location in the tree is no longer valid here. But
    // we can't unfocus or remove the node from the tree because if the widget
    // is moved to a different part of the tree (via global key) it should
    // retain its focus state. That's why we temporarily park it on the root
    // focus node (via reparent) until it either gets moved to a different part
    // of the tree (via didChangeDependencies) or until it is disposed.
    _focusAttachment.reparent();
    _didAutofocus = false;
  }

  @override
  void dispose() {
    // Regardless of the node owner, we need to remove it from the tree and stop
    // listening to it.
    focusNode.removeListener(_handleFocusChanged);
    _focusAttachment.detach();

    // Don't manage the lifetime of external nodes given to the widget, just the
    // internal node.
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleAutofocus() {
    if (!_didAutofocus && widget.autofocus) {
      FocusScope.of(context).autofocus(focusNode);
      _didAutofocus = true;
    }
  }

  void _handleFocusChanged() {
    final bool hasPrimaryFocus = focusNode.hasPrimaryFocus;
    final bool canRequestFocus = focusNode.canRequestFocus;
    final bool descendantsAreFocusable = focusNode.descendantsAreFocusable;
    final bool descendantsAreTraversable = focusNode.descendantsAreTraversable;
    widget.onFocusChange?.call(focusNode.hasFocus);
    // Check the cached states that matter here, and call setState if they have
    // changed.
    if (_hadPrimaryFocus != hasPrimaryFocus) {
      setState(() {
        _hadPrimaryFocus = hasPrimaryFocus;
      });
    }
    if (_couldRequestFocus != canRequestFocus) {
      setState(() {
        _couldRequestFocus = canRequestFocus;
      });
    }
    if (_descendantsWereFocusable != descendantsAreFocusable) {
      setState(() {
        _descendantsWereFocusable = descendantsAreFocusable;
      });
    }
    if (_descendantsWereTraversable != descendantsAreTraversable) {
      setState(() {
        _descendantsWereTraversable = descendantsAreTraversable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parentFocusNode == null) {
      _focusAttachment.reparent();
    }

    Widget child = widget.child;
    if (widget.includeSemantics) {
      child = Semantics(
        focusable: _couldRequestFocus,
        focused: _hadPrimaryFocus,
        child: widget.child,
      );
    }
    return _FocusMarker(
      node: focusNode,
      child: child,
    );
  }
}

// The InheritedWidget marker for Focus and FocusScope.
class _FocusMarker extends InheritedNotifier<FocusNode> {
  const _FocusMarker({
    Key? key,
    required FocusNode node,
    required Widget child,
  }) : super(key: key, notifier: node, child: child);
}
