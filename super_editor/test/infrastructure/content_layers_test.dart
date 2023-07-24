import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';

void main() {
  group("Content layers", () {
    testWidgets("build without any layers", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => LayoutBuilder(
            builder: (context, constraints) {
              // The content should be able to take up whatever size it wants, within the available space.
              expect(constraints.isTight, isFalse);
              expect(constraints.maxWidth, _windowSize.width);
              expect(constraints.maxHeight, _windowSize.height);

              return const SizedBox.expand();
            },
          ),
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("build with a single underlay and is same size as content", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => const SizedBox.expand(),
          underlays: [
            _buildSizeValidatingLayer(),
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("build with a single overlay and is same size as content", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => const SizedBox.expand(),
          overlays: [
            _buildSizeValidatingLayer(),
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("build with a single underlay and overlay and they are the same size as content", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => const SizedBox.expand(),
          underlays: [
            _buildSizeValidatingLayer(),
          ],
          overlays: [
            _buildSizeValidatingLayer(),
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("build with multiple underlays and overlays and they are the same size as content", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => const SizedBox.expand(),
          underlays: [
            _buildSizeValidatingLayer(),
            _buildSizeValidatingLayer(),
            _buildSizeValidatingLayer(),
          ],
          overlays: [
            _buildSizeValidatingLayer(),
            _buildSizeValidatingLayer(),
            _buildSizeValidatingLayer(),
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("rebuilds layers when they setState()", (tester) async {
      final contentRebuildSignal = ValueNotifier<int>(0);
      final contentBuildTracker = ValueNotifier<int>(0);

      final underlayRebuildSignal = ValueNotifier<int>(0);
      final underlayBuildTracker = ValueNotifier<int>(0);

      final overlayRebuildSignal = ValueNotifier<int>(0);
      final overlayBuildTracker = ValueNotifier<int>(0);

      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (onBuildScheduled) => _RebuildableWidget(
            rebuildSignal: contentRebuildSignal,
            buildTracker: contentBuildTracker,
            onBuildScheduled: onBuildScheduled,
            child: const SizedBox(),
          ),
          underlays: [
            (context) => _RebuildableWidget(
                  rebuildSignal: underlayRebuildSignal,
                  buildTracker: underlayBuildTracker,
                  child: const SizedBox(),
                ),
          ],
          overlays: [
            (context) => _RebuildableWidget(
                  rebuildSignal: overlayRebuildSignal,
                  buildTracker: overlayBuildTracker,
                  child: const SizedBox(),
                ),
          ],
        ),
      );
      expect(contentBuildTracker.value, 1);
      expect(underlayBuildTracker.value, 1);
      expect(overlayBuildTracker.value, 1);

      // Tell the underlay widget to rebuild itself.
      underlayRebuildSignal.value += 1;
      await tester.pump();
      expect(underlayBuildTracker.value, 2);
      expect(contentBuildTracker.value, 1);

      // Tell the overlay widget to rebuild itself.
      overlayRebuildSignal.value += 1;
      await tester.pump();
      expect(overlayBuildTracker.value, 2);
      expect(contentBuildTracker.value, 1);
    });

    testWidgets("lays out the content before building the layers during full tree build", (tester) async {
      final didContentLayout = ValueNotifier<bool>(false);
      bool didUnderlayLayout = false;

      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => _LayoutTrackingWidget(
            onLayout: () {
              didContentLayout.value = true;
            },
            child: const SizedBox.expand(),
          ),
          underlays: [
            (context) {
              expect(didContentLayout.value, isTrue);
              didUnderlayLayout = true;
              return const SizedBox();
            },
          ],
          overlays: [
            (context) {
              expect(didContentLayout.value, isTrue);
              expect(didUnderlayLayout, isTrue);
              return const SizedBox();
            },
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });

    testWidgets("lays out the content before building the layers when the content root rebuilds", (tester) async {
      final rebuildSignal = ValueNotifier<int>(0);
      final buildTracker = ValueNotifier<int>(0);
      final contentLayoutCount = ValueNotifier<int>(0);
      final layerLayoutCount = ValueNotifier<int>(0);

      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (onBuildScheduled) => _RebuildableWidget(
            rebuildSignal: rebuildSignal,
            buildTracker: buildTracker,
            onBuildScheduled: onBuildScheduled,
            child: _LayoutTrackingWidget(
              onLayout: () {
                contentLayoutCount.value += 1;
              },
              child: const SizedBox.expand(),
            ),
          ),
          underlays: [
            (context) {
              expect(contentLayoutCount.value, layerLayoutCount.value + 1);
              return const SizedBox();
            },
          ],
          overlays: [
            (context) {
              expect(contentLayoutCount.value, layerLayoutCount.value + 1);
              layerLayoutCount.value += 1;
              return const SizedBox();
            },
          ],
        ),
      );
      expect(buildTracker.value, 1);

      // Tell the content widget to rebuild itself.
      rebuildSignal.value += 1;
      await tester.pump();

      // We expect build and layout to run twice. First, during the initial pump. Second,
      // after we tell the content to rebuild.
      expect(buildTracker.value, 2);
      expect(contentLayoutCount.value, 2);
      expect(layerLayoutCount.value, 2);
    });

    testWidgets("lays out the content before building the layers when a content descendant rebuilds", (tester) async {
      final rebuildSignal = ValueNotifier<int>(0);
      final buildTracker = ValueNotifier<int>(0);
      final contentLayoutCount = ValueNotifier<int>(0);
      final layerLayoutCount = ValueNotifier<int>(0);

      await _pumpScaffold(
        tester,
        child: ContentLayers(
          // Place a couple stateful widgets above the _RebuildableWidget to ensure that
          // when a widget deeper in the tree rebuilds, we still rebuild ContentLayers.
          content: (_) => _NoRebuildWidget(
            child: _NoRebuildWidget(
              child: _RebuildableWidget(
                rebuildSignal: rebuildSignal,
                buildTracker: buildTracker,
                // We don't pass in the onBuildScheduled callback here because we're simulating
                // an entire subtree that a client might provide as content.
                child: _LayoutTrackingWidget(
                  onLayout: () {
                    contentLayoutCount.value += 1;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          underlays: [
            (context) {
              expect(contentLayoutCount.value, layerLayoutCount.value + 1);
              return const SizedBox();
            },
          ],
          overlays: [
            (context) {
              expect(contentLayoutCount.value, layerLayoutCount.value + 1);
              layerLayoutCount.value += 1;
              return const SizedBox();
            },
          ],
        ),
      );
      expect(buildTracker.value, 1);
      expect(contentLayoutCount.value, 1);
      expect(layerLayoutCount.value, 1);

      // Tell the content widget to rebuild itself.
      rebuildSignal.value += 1;
      await tester.pump();

      // We expect build and layout to run twice. First, during the initial pump. Second,
      // after we tell the content to rebuild.
      expect(buildTracker.value, 2);
      expect(contentLayoutCount.value, 2);
      expect(layerLayoutCount.value, 2);
    });

    testWidgets("re-uses layer Elements instead of always re-inflating layer Widgets", (tester) async {
      final rebuildSignal = ValueNotifier<int>(0);
      final buildTracker = ValueNotifier<int>(0);
      final contentLayoutCount = ValueNotifier<int>(0);
      final underlayElementTracker = ValueNotifier<Element?>(null);
      Element? underlayElement;
      final overlayElementTracker = ValueNotifier<Element?>(null);
      Element? overlayElement;

      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => _RebuildableWidget(
            rebuildSignal: rebuildSignal,
            buildTracker: buildTracker,
            // We don't pass in the onBuildScheduled callback here because we're simulating
            // an entire subtree that a client might provide as content.
            child: _LayoutTrackingWidget(
              onLayout: () {
                contentLayoutCount.value += 1;
              },
              child: const SizedBox.expand(),
            ),
          ),
          underlays: [
            (context) => _RebuildableWidget(
                  elementTracker: underlayElementTracker,
                  child: const SizedBox.expand(),
                ),
          ],
          overlays: [
            (context) => _RebuildableWidget(
                  elementTracker: overlayElementTracker,
                  child: const SizedBox.expand(),
                ),
          ],
        ),
      );
      expect(buildTracker.value, 1);

      underlayElement = underlayElementTracker.value;
      expect(underlayElement, isNotNull);

      overlayElement = overlayElementTracker.value;
      expect(overlayElement, isNotNull);

      // Tell the content widget to rebuild itself.
      rebuildSignal.value += 1;
      await tester.pump();

      // We expect build and layout to run twice. First, during the initial pump. Second,
      // after we tell the content to rebuild.
      expect(buildTracker.value, 2);
      expect(contentLayoutCount.value, 2);
      expect(underlayElementTracker.value, underlayElement);
      expect(overlayElementTracker.value, overlayElement);
    });

    testWidgets("lets layers access inherited widgets", (tester) async {
      await _pumpScaffold(
        tester,
        child: ContentLayers(
          content: (_) => const SizedBox.expand(),
          underlays: [
            (context) {
              final directionality = Directionality.of(context);
              expect(directionality, isNotNull);
              return const SizedBox();
            },
          ],
          overlays: [
            (context) {
              final directionality = Directionality.of(context);
              expect(directionality, isNotNull);
              return const SizedBox();
            },
          ],
        ),
      );

      // Getting here without an error means the test passes.
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required Widget child,
}) async {
  addTearDown(() => tester.platformDispatcher.clearAllTestValues());

  tester.view
    ..physicalSize = _windowSize
    ..devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

// We control the window size in these tests so that we can easily compare and validate
// the layout sizes for underlays and overlays.
const _windowSize = Size(600, 1000);

/// Returns a [LayoutBuilder] that expects its constraints to be the same as the window,
/// used for quickly verifying the constraints given to underlays and overlays in
/// ContentLayers widgets in this test suite.
WidgetBuilder _buildSizeValidatingLayer() {
  return (context) => LayoutBuilder(
        builder: (context, constraints) {
          _expectLayerConstraintsThatMatchContent(constraints);
          return const SizedBox();
        },
      );
}

void _expectLayerConstraintsThatMatchContent(BoxConstraints constraints) {
  expect(constraints.isTight, isTrue);
  expect(constraints.maxWidth, _windowSize.width);
  expect(constraints.maxHeight, _windowSize.height);
}

/// A [StatefulWidget] that never rebuilds.
///
/// Used to inject an `Element` above another widget to test what happens when a descendant
/// rebuilds, and that descendant isn't the top-level widget in a subtree.
class _NoRebuildWidget extends StatefulWidget {
  const _NoRebuildWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  State<_NoRebuildWidget> createState() => _NoRebuildWidgetState();
}

class _NoRebuildWidgetState extends State<_NoRebuildWidget> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that can be told to rebuild from the outside, and also tracks its build count.
class _RebuildableWidget extends StatefulWidget {
  const _RebuildableWidget({
    Key? key,
    this.rebuildSignal,
    this.buildTracker,
    this.elementTracker,
    this.onBuildScheduled,
    required this.child,
  }) : super(key: key);

  final Listenable? rebuildSignal;
  final ValueNotifier<int>? buildTracker;
  final ValueNotifier<Element?>? elementTracker;
  final VoidCallback? onBuildScheduled;
  final Widget child;

  @override
  State<_RebuildableWidget> createState() => _RebuildableWidgetState();
}

class _RebuildableWidgetState extends State<_RebuildableWidget> {
  @override
  void initState() {
    super.initState();
    widget.rebuildSignal?.addListener(_onRebuildSignal);
  }

  @override
  void didUpdateWidget(_RebuildableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rebuildSignal != oldWidget.rebuildSignal) {
      oldWidget.rebuildSignal?.removeListener(_onRebuildSignal);
      widget.rebuildSignal?.addListener(_onRebuildSignal);
    }
  }

  @override
  void dispose() {
    widget.rebuildSignal?.removeListener(_onRebuildSignal);
    super.dispose();
  }

  void _onRebuildSignal() {
    setState(() {
      // rebuild
    });

    // Explicitly mark our RenderObject as needing layout so that we simulate content
    // that rebuilds because its layout changed. Without this call, we'd get a widget
    // rebuild, but we wouldn't trigger another content layout pass. We want that
    // layout pass so that our tests can inspect the order of operations and ensure that
    // when the content layout changes, the content is always laid out before layers.
    context.findRenderObject()?.markNeedsLayout();
  }

  // This override is a regrettable requirement for ContentLayers, which is needed so
  // that ContentLayers can remove the layers to prevent them from building during a
  // regular build phase when the content changes. This is the result of Flutter making
  // it impossible to monitor dirty subtrees, and making it impossible to control build
  // order.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onBuildScheduled?.call();
  }

  @override
  Widget build(BuildContext context) {
    widget.buildTracker?.value += 1;
    widget.elementTracker?.value = context as Element;
    return widget.child;
  }
}

/// Widget that reports every time it runs layout.
class _LayoutTrackingWidget extends SingleChildRenderObjectWidget {
  const _LayoutTrackingWidget({
    required this.onLayout,
    required Widget child,
  }) : super(child: child);

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutTrackingWidget(onLayout);
  }
}

class _RenderLayoutTrackingWidget extends RenderProxyBox {
  _RenderLayoutTrackingWidget(this._onLayout);

  final VoidCallback _onLayout;

  @override
  void performLayout() {
    _onLayout();
    super.performLayout();
  }
}
