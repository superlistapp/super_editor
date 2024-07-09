import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';

void main() {
  group("Multi tap gesture", () {
    final tapTargetFinder = find.byKey(const ValueKey('tap-target'));

    testWidgets("can report preceding gestures", (tester) async {
      final recognizer = TapSequenceGestureRecognizer(
        supportedDevices: {PointerDeviceKind.touch},
        reportPrecedingGestures: true,
      );
      int tapDownCount = 0;
      int tapCount = 0;
      int doubleTapDownCount = 0;
      int doubleTapCount = 0;
      int tripleTapDownCount = 0;
      int tripleTapCount = 0;

      await tester.pumpWidget(
        _buildGestureScaffold(
          recognizer,
          onTapDown: (_) {
            tapDownCount += 1;
          },
          onTap: () {
            tapCount += 1;
          },
          onDoubleTapDown: (_) {
            doubleTapDownCount += 1;
          },
          onDoubleTap: () {
            doubleTapCount += 1;
          },
          onTripleTapDown: (_) {
            tripleTapDownCount += 1;
          },
          onTripleTap: () {
            tripleTapCount += 1;
          },
        ),
      );

      TestGesture gesture = await tester.startGesture(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.down(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 1);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 1);
      expect(doubleTapCount, 1);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.down(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 1);
      expect(doubleTapCount, 1);
      expect(tripleTapDownCount, 1);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 1);
      expect(doubleTapCount, 1);
      expect(tripleTapDownCount, 1);
      expect(tripleTapCount, 1);

      await tester.pumpAndSettle();
    });

    testWidgets("reports single tap after timeout", (tester) async {
      final recognizer = TapSequenceGestureRecognizer(
        supportedDevices: {PointerDeviceKind.touch},
        reportPrecedingGestures: false,
      );

      int tapDownCount = 0;
      int tapCount = 0;
      int doubleTapDownCount = 0;
      int doubleTapCount = 0;
      int tripleTapDownCount = 0;
      int tripleTapCount = 0;
      int timeoutCount = 0;

      await tester.pumpWidget(
        _buildGestureScaffold(recognizer, onTapDown: (_) {
          tapDownCount += 1;
        }, onTap: () {
          tapCount += 1;
        }, onDoubleTapDown: (_) {
          doubleTapDownCount += 1;
        }, onDoubleTap: () {
          doubleTapCount += 1;
        }, onTripleTapDown: (_) {
          tripleTapDownCount += 1;
        }, onTripleTap: () {
          tripleTapCount += 1;
        }, onTimeout: () {
          timeoutCount += 1;
        }),
      );

      TestGesture gesture = await tester.startGesture(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);
      expect(timeoutCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);
      expect(timeoutCount, 0);

      // Cause a timeout that should cause the recognizer to stop
      // looking for the triple tap and then report just the double tap.
      await tester.pump(kTapTimeout);
      await tester.pumpAndSettle();

      expect(tapDownCount, 1);
      expect(tapCount, 1);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);
      expect(timeoutCount, 1);
    });

    testWidgets("can ignore single tap gesture", (tester) async {
      final recognizer = TapSequenceGestureRecognizer(
        supportedDevices: {PointerDeviceKind.touch},
        reportPrecedingGestures: false,
      );

      int tapDownCount = 0;
      int tapCount = 0;
      int doubleTapDownCount = 0;
      int doubleTapCount = 0;
      int tripleTapDownCount = 0;
      int tripleTapCount = 0;
      int timeoutCount = 0;

      await tester.pumpWidget(
        _buildGestureScaffold(
          recognizer,
          onTapDown: (_) {
            tapDownCount += 1;
          },
          onTap: () {
            tapCount += 1;
          },
          onDoubleTapDown: (_) {
            doubleTapDownCount += 1;
          },
          onDoubleTap: () {
            doubleTapCount += 1;
          },
          onTripleTapDown: (_) {
            tripleTapDownCount += 1;
          },
          onTripleTap: () {
            tripleTapCount += 1;
          },
          onTimeout: () {
            timeoutCount += 1;
          },
        ),
      );

      TestGesture gesture = await tester.startGesture(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.down(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      // Cause a timeout that should cause the recognizer to stop
      // looking for the triple tap and then report just the double tap.
      await tester.pump(kTapTimeout);
      await tester.pumpAndSettle();

      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 1);
      expect(doubleTapCount, 1);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);
      expect(timeoutCount, 1);
    });

    testWidgets("can ignore single tap and double tap gestures", (tester) async {
      final recognizer = TapSequenceGestureRecognizer(
        supportedDevices: {PointerDeviceKind.touch},
        reportPrecedingGestures: false,
      );

      int tapDownCount = 0;
      int tapCount = 0;
      int doubleTapDownCount = 0;
      int doubleTapCount = 0;
      int tripleTapDownCount = 0;
      int tripleTapCount = 0;
      int timeoutCount = 0;

      await tester.pumpWidget(
        _buildGestureScaffold(
          recognizer,
          onTapDown: (_) {
            tapDownCount += 1;
          },
          onTap: () {
            tapCount += 1;
          },
          onDoubleTapDown: (_) {
            doubleTapDownCount += 1;
          },
          onDoubleTap: () {
            doubleTapCount += 1;
          },
          onTripleTapDown: (_) {
            tripleTapDownCount += 1;
          },
          onTripleTap: () {
            tripleTapCount += 1;
          },
          onTimeout: () {
            timeoutCount += 1;
          },
        ),
      );

      TestGesture gesture = await tester.startGesture(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.down(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 0);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.down(tester.getCenter(tapTargetFinder));
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 1);
      expect(tripleTapCount, 0);

      await tester.pump(kTapMinTime);
      await gesture.up();
      await tester.pump();
      expect(tapDownCount, 0);
      expect(tapCount, 0);
      expect(doubleTapDownCount, 0);
      expect(doubleTapCount, 0);
      expect(tripleTapDownCount, 1);
      expect(tripleTapCount, 1);
      expect(timeoutCount, 0); // No timeout when we get to the final gesture

      await tester.pumpAndSettle();
    });

    testWidgets("cancels tap if another recognizer wins after tap down", (tester) async {
      int tapDownCount = 0;
      int tapCancelCount = 0;
      int tapUpCount = 0;
      int dragUpdateCount = 0;

      // Pump a tree with a tap recognizer and a drag recognizer to check if dragging
      // after onTapDown was called causes the tap to be cancelled.
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RawGestureDetector(
              gestures: {
                HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                  (HorizontalDragGestureRecognizer recognizer) {
                    recognizer.onUpdate = (_) {
                      dragUpdateCount += 1;
                    };
                  },
                ),
                TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
                  () => TapSequenceGestureRecognizer(),
                  (TapSequenceGestureRecognizer recognizer) {
                    recognizer
                      ..onTapDown = (_) {
                        tapDownCount += 1;
                      }
                      ..onTapUp = (_) {
                        tapUpCount += 1;
                      }
                      ..onTapCancel = () {
                        tapCancelCount += 1;
                      };
                  },
                ),
              },
              child: Container(
                key: const ValueKey('tap-target'),
                width: 48,
                height: 48,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      // Start the gesture, this should fire onTapDown.
      final gesture = await tester.startGesture(tester.getCenter(tapTargetFinder));
      await tester.pump(kTapMinTime);

      // Trigger a horizontal drag.
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      // Release the gesture.
      await gesture.up();
      await tester.pump();

      // Ensure that onTapCancel was called and onTapUp was not.
      expect(tapDownCount, 1);
      expect(tapCancelCount, 1);
      expect(tapUpCount, 0);
      expect(dragUpdateCount, 1);
    });
  });
}

Widget _buildGestureScaffold(
  TapSequenceGestureRecognizer recognizer, {
  GestureTapDownCallback? onTapDown,
  VoidCallback? onTap,
  GestureTapDownCallback? onDoubleTapDown,
  VoidCallback? onDoubleTap,
  GestureTapDownCallback? onTripleTapDown,
  VoidCallback? onTripleTap,
  VoidCallback? onTimeout,
}) {
  return MaterialApp(
    home: Center(
      child: RawGestureDetector(
        gestures: {
          TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
            () => recognizer,
            (TapSequenceGestureRecognizer recognizer) {
              recognizer
                ..onTapDown = onTapDown
                ..onTap = onTap
                ..onDoubleTapDown = onDoubleTapDown
                ..onDoubleTap = onDoubleTap
                ..onTripleTapDown = onTripleTapDown
                ..onTripleTap = onTripleTap
                ..onTimeout = onTimeout;
            },
          ),
        },
        child: Container(
          key: const ValueKey('tap-target'),
          width: 48,
          height: 48,
          color: Colors.red,
        ),
      ),
    ),
  );
}
