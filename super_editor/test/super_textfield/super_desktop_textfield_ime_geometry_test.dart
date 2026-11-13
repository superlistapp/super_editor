import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_text_field_test.dart';

void main() {
  for (final invalid in [double.nan, double.infinity, double.negativeInfinity]) {
    testWidgets('SuperDesktopTextField IME geometry recovers after $invalid transform', (tester) async {
      final transform = ValueNotifier<double>(0);
      addTearDown(transform.dispose);
      final controller = ImeAttributedTextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: _GeometryTransform(
                value: transform,
                child: SuperTextField(
                  textController: controller,
                  inputSource: TextInputSource.ime,
                  lineHeight: 18,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.placeCaretInSuperTextField(0);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(_geometryCalls(tester), isNotEmpty);
      final initialTranslation = _geometryCalls(tester).last.arguments['transform'][12] as num;

      tester.testTextInput.log.clear();
      transform.value = invalid;
      tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
      tester.binding.scheduleFrame();
      await tester.pump();
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_geometryCalls(tester), isEmpty);

      transform.value = 10;
      tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(tester.takeException(), isNull);
      final reported = (_geometryCalls(tester).last.arguments['transform'] as List).cast<num>();
      expect(reported.every((value) => value.isFinite), isTrue);
      expect(reported[12], initialTranslation + 10);

      await tester.pumpWidget(const SizedBox());
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.desktop(), semanticsEnabled: false);
  }
}

Iterable<MethodCall> _geometryCalls(WidgetTester tester) =>
    tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform');

class _GeometryTransform extends SingleChildRenderObjectWidget {
  const _GeometryTransform({required this.value, required super.child});
  final ValueNotifier<double> value;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGeometryTransform(value);
}

class _RenderGeometryTransform extends RenderProxyBox {
  _RenderGeometryTransform(this.value);
  final ValueNotifier<double> value;
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    transform.translateByDouble(value.value, 0, 0, 1);
  }
}
