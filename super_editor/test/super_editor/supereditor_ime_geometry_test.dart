import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  for (final dimension in ['width', 'height']) {
    for (final invalid in [double.nan, double.infinity, double.negativeInfinity]) {
      testWidgets('IME recovers after non-finite $dimension: $invalid', (tester) async {
        final size = ValueNotifier<Size>(const Size(300, 100));
        final focus = FocusNode();
        final document = MutableDocument.empty();
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);
        final scroller = DocumentScroller();
        addTearDown(size.dispose);
        addTearDown(focus.dispose);
        addTearDown(composer.dispose);
        addTearDown(scroller.dispose);
        final context = SuperEditorContext(
          editorFocusNode: focus,
          editor: editor,
          document: document,
          getDocumentLayout: () => throw StateError('No selection needs layout'),
          composer: composer,
          scroller: scroller,
          commonOps: CommonEditorOperations(
            editor: editor,
            document: document,
            composer: composer,
            documentLayoutResolver: () => throw StateError('No selection needs layout'),
          ),
        );
        await tester.pumpWidget(MaterialApp(
            home: CustomScrollView(slivers: [
          SuperEditorImeInteractor(
            focusNode: focus,
            editContext: context,
            selectorHandlers: const {},
            child: _ReportedSize(size),
          ),
        ])));
        focus.requestFocus();
        tester.binding.scheduleFrame();
        await tester.pump();
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(_geometryCalls(tester).last.arguments['width'], 300);
        expect(_geometryCalls(tester).last.arguments['height'], 100);
        tester.testTextInput.log.clear();
        size.value = dimension == 'width' ? Size(invalid, 100) : Size(300, invalid);
        tester.binding.scheduleFrame();
        await tester.pump();
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_geometryCalls(tester), isEmpty);
        size.value = const Size(320, 120);
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_geometryCalls(tester).last.arguments['width'], 320);
        expect(_geometryCalls(tester).last.arguments['height'], 120);
        expect(
            (_geometryCalls(tester).last.arguments['transform'] as List).cast<num>().every((n) => n.isFinite), isTrue);
        await tester.pumpWidget(const SizedBox());
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

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
        final initialTranslation = _geometryCalls(tester).last.arguments['transform'][12] as num;
        tester.testTextInput.log.clear();
        transform.value = invalid;
        tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
            tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform'), isEmpty);
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        transform.value = 10;
        tester.renderObject(find.byType(_GeometryTransform)).markNeedsLayout();
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform'),
            isNotEmpty);
        final reportedTransform = (_geometryCalls(tester).last.arguments['transform'] as List).cast<num>();
        expect(reportedTransform.every((value) => value.isFinite), isTrue);
        expect(reportedTransform[12], initialTranslation + 10);
        await tester.typeImeText('Recovered');
        expect(SuperEditorInspector.findDocument()!.first,
            isA<ParagraphNode>().having((node) => node.text.toPlainText(), 'text', startsWith('Recovered')));
        await tester.pumpWidget(const SizedBox());
        tester.binding.scheduleFrame();
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

Iterable<MethodCall> _geometryCalls(WidgetTester tester) =>
    tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditableSizeAndTransform');

class _ReportedSize extends LeafRenderObjectWidget {
  const _ReportedSize(this.size);
  final ValueNotifier<Size> size;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportedSize(size);
}

class _RenderReportedSize extends RenderSliver {
  _RenderReportedSize(this.reportedSize);
  final ValueNotifier<Size> reportedSize;

  // Inject invalid dimensions only at the IME reporting boundary, so Flutter's
  // layout assertions don't prevent exercising the serialization path.
  @override
  SliverGeometry? get geometry => SchedulerBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks
      ? SliverGeometry(crossAxisExtent: reportedSize.value.width, paintExtent: reportedSize.value.height)
      : super.geometry;

  @override
  void performLayout() {
    geometry = const SliverGeometry(scrollExtent: 100, paintExtent: 100, maxPaintExtent: 100);
  }
}
