import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  for (final platform in WebPlatformOverride.values) {
    for (final invalid in [double.nan, double.infinity, double.negativeInfinity]) {
      testWidgets('IME geometry recovers after $invalid transform on $platform', (tester) async {
        debugIsWebOverride = platform;
        addTearDown(() => debugIsWebOverride = null);
        final transform = ValueNotifier<double>(0);
        addTearDown(transform.dispose);
        await tester
            .createDocument()
            .withSingleParagraph()
            .withInputSource(TextInputSource.ime)
            .withCustomWidgetTreeBuilder((editor) => MaterialApp(
                    home: Scaffold(
                  body: _GeometryTransform(value: transform, child: editor),
                )))
            .pump();
        await tester.placeCaretInParagraph('1', 0);
        expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform'),
            isNotEmpty);
        tester.testTextInput.log.clear();
        transform.value = invalid;
        tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
            tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform'), isEmpty);
        await tester.pump();
        expect(tester.takeException(), isNull);
        transform.value = 10;
        tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform'),
            isNotEmpty);
        await tester.typeImeText('Recovered');
        expect(SuperEditorInspector.findDocument()!.first,
            isA<ParagraphNode>().having((node) => node.text.toPlainText(), 'text', startsWith('Recovered')));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      }, semanticsEnabled: false);
    }
  }
}

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
    transform.setEntry(0, 3, value.value);
  }
}
