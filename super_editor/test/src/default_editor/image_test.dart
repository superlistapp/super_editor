import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/test_documents.dart';
import '../../test_tools.dart';

void main() {
  group('SuperEditor image component', () {
    testWidgetsOnArbitraryDesktop('scrolls on mouse wheel', (tester) async {
      final controller = ScrollController();

      await _pumpScaffold(tester, scrollController: controller);

      // Ensure the document started without any scrolling.
      expect(controller.offset, 0.0);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      // Hover the image.
      pointer.hover(tester.getCenter(find.byType(ImageComponent)));
      await tester.pump();

      // Simulate scrolling with mouse wheel.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0.0, 50.0)));
      await tester.pumpAndSettle();

      // Ensure the document scrolled down.
      expect(controller.offset, greaterThan(0.0));
    });

    testWidgetsOnArbitraryDesktop('has basic mouse cursor', (tester) async {
      await _pumpScaffold(tester);

      // Start a gesture outside the image bounds. (The image is 100x100)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(0, 110));
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'text' when not hovering the image.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Hover the image.
      await gesture.moveTo(tester.getCenter(find.byType(ImageComponent)));
      await tester.pump();

      // Ensure the cursor type is 'basic' when hovering the image.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });
  });
}

/// Pump a SuperEditor containing an image which will render as an 100x100 box
/// and content big enough to cause the document to be scrollable.
Future<void> _pumpScaffold(
  WidgetTester tester, {
  ScrollController? scrollController,
}) async {
  await tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ImageNode(
              id: "img-node",
              imageUrl: 'https://this.is.a.fake.image',
              metadata: const SingleColumnLayoutComponentStyles(
                width: double.infinity,
              ).toMetadata(),
            ),
            ...longTextDoc().nodes,
          ],
        ),
      )
      .withAddedComponents([const _FakeImageComponentBuilder()])
      .withEditorSize(const Size(300, 300))
      .withScrollController(scrollController)
      .pump();
}

/// A [ComponentBuilder] which builds an [ImageComponent] that always renders 
/// images as an 100x100 [SizedBox].
class _FakeImageComponentBuilder implements ComponentBuilder {
  const _FakeImageComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    return null;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ImageComponentViewModel) {
      return null;
    }

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: componentViewModel.imageUrl,
      selection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      imageBuilder: (context, imageUrl) => const SizedBox(height: 100, width: 100),
    );
  }
}
