import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/src/infrastructure/scrolling_diagnostics/_scrolling_minimap.dart';

void main() {
  const minimapScale = 0.1;

  group("Scrolling minimap widget", () {
    testGoldens("renders with content height", (tester) async {
      final scrollableKey = GlobalKey(debugLabel: "scrollable");
      final scrollController = ScrollController();
      final minimapKey = GlobalKey(debugLabel: "scrolling_minimap");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: scrollableKey,
                    controller: scrollController,
                    child: Container(
                      width: double.infinity,
                      height: 1500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                // This is where the minimap will be added in the next frame.
                const SizedBox(
                  width: 250,
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      final scrollableInstrumentation = ScrollableInstrumentation()
        ..scrollable.value = scrollableKey.currentState as ScrollableState?;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: scrollableKey,
                    controller: scrollController,
                    child: Container(
                      width: double.infinity,
                      height: 1500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Center(
                    child: ScrollingMinimap(
                      key: minimapKey,
                      instrumentation: scrollableInstrumentation,
                      minimapScale: minimapScale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      // Let the minimap update its display
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, "scrolling-minimap_with-content-height_no-scroll");
    });

    testGoldens("renders with content height, scrolled", (tester) async {
      final scrollableKey = GlobalKey(debugLabel: "scrollable");
      final scrollController = ScrollController();
      final minimapKey = GlobalKey(debugLabel: "scrolling_minimap");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: scrollableKey,
                    controller: scrollController,
                    child: Container(
                      width: double.infinity,
                      height: 1500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                // This is where the minimap will go on the next frame.
                const SizedBox(
                  width: 250,
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      final scrollableInstrumentation = ScrollableInstrumentation()
        ..scrollable.value = scrollableKey.currentState as ScrollableState?;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: scrollableKey,
                    controller: scrollController,
                    child: Container(
                      width: double.infinity,
                      height: 1500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Center(
                    child: ScrollingMinimap(
                      key: minimapKey,
                      instrumentation: scrollableInstrumentation,
                      minimapScale: minimapScale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      // Scroll the Scrollable
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, "scrolling-minimap_with-content-height_scrolled");
    });

    testGoldens("renders without content height, scrolled", (tester) async {
      final scrollableKey = GlobalKey(debugLabel: "scrollable");
      final scrollController = ScrollController();
      final minimapKey = GlobalKey(debugLabel: "scrolling_minimap");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListView.builder(
                    key: scrollableKey,
                    controller: scrollController,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text("Item $index"),
                      );
                    },
                  ),
                ),
                // This is where the minimap will go on the next frame.
                const SizedBox(
                  width: 250,
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      final scrollableInstrumentation = ScrollableInstrumentation()
        ..scrollable.value = scrollableKey.currentState as ScrollableState?;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListView.builder(
                    key: scrollableKey,
                    controller: scrollController,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text("Item $index"),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Center(
                    child: ScrollingMinimap(
                      key: minimapKey,
                      instrumentation: scrollableInstrumentation,
                      minimapScale: minimapScale,
                    ),
                  ),
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      // Scroll the Scrollable
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, "scrolling-minimap_without-content-height_scrolled");
    });
  });

  group("Scrolling minimap painter", () {
    const hypotheticalViewportSize = Size(800, 600);

    testGoldens("renders with content height", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    contentHeight: 1500,
                    scrollOffset: 0,
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_with-content-height_no-scroll");
    });

    testGoldens("renders with content height, scrolled", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    contentHeight: 1500,
                    scrollOffset: 500,
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_with-content-height_scrolled");
    });

    testGoldens("renders with content height, scrolled, with drag", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    contentHeight: 1500,
                    scrollOffset: 500,
                    viewportStartDragOffset: const Offset(300, 200),
                    viewportEndDragOffset: const Offset(400, 500),
                    contentStartDragOffset: const Offset(300, 200) - const Offset(0, 500),
                    contentEndDragOffset: const Offset(400, 500),
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_with-content-height_scrolled_with-drag");
    });

    testGoldens("renders with content height, scrolled, with autoscroll down", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    contentHeight: 1500,
                    scrollOffset: 500,
                    viewportStartDragOffset: const Offset(300, 200),
                    viewportEndDragOffset: const Offset(400, 500),
                    contentStartDragOffset: const Offset(300, 200) - const Offset(0, 500),
                    contentEndDragOffset: const Offset(400, 500),
                    autoScrollingEdge: ViewportEdge.trailing,
                    scrollingDirection: ScrollDirection.forward,
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_with-content-height_scrolled_with-autoscroll-down");
    });

    testGoldens("renders with content height, scrolled, with autoscroll up", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    contentHeight: 1500,
                    scrollOffset: 500,
                    viewportStartDragOffset: const Offset(300, 200),
                    viewportEndDragOffset: const Offset(400, 500),
                    contentStartDragOffset: const Offset(300, 200) - const Offset(0, 500),
                    contentEndDragOffset: const Offset(400, 500),
                    autoScrollingEdge: ViewportEdge.leading,
                    scrollingDirection: ScrollDirection.reverse,
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_with-content-height_scrolled_with-autoscroll-up");
    });

    testGoldens("renders without content height, scrolled, with drag", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: hypotheticalViewportSize * minimapScale,
                child: CustomPaint(
                  painter: ScrollingMinimapPainter(
                    viewportSize: hypotheticalViewportSize,
                    scrollOffset: 500,
                    viewportStartDragOffset: const Offset(300, 200),
                    viewportEndDragOffset: const Offset(400, 500),
                    contentStartDragOffset: const Offset(300, 200) - const Offset(0, 500),
                    contentEndDragOffset: const Offset(400, 500),
                    minimapScale: minimapScale,
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );

      await screenMatchesGolden(tester, "scrolling-minimap-painter_no-content-height_scrolled_with-drag");
    });
  });
}
