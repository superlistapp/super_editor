import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:follow_the_leader/follow_the_leader.dart';

import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/infrastructure/default_popovers.dart';
import 'package:super_editor/src/infrastructure/popover_scaffold.dart';
import 'package:super_editor/src/infrastructure/selectable_list.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';

import '../super_editor/test_documents.dart';

void main() {
  group('PopoverScaffold', () {
    testWidgetsOnAllPlatforms('opens and closes the popover when requested', (tester) async {
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopoverScaffold(
              controller: popoverController,
              buttonBuilder: (context) => const SizedBox(),
              popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pump();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      // Close the popover.
      popoverController.close();
      await tester.pump();

      // Ensure the popover was closed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);
    });

    testWidgetsOnAllPlatforms('closes the popover when tapping outside', (tester) async {
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: PopoverScaffold(
                  controller: popoverController,
                  buttonBuilder: (context) => const SizedBox(),
                  popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                    child: SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      // Taps outside of the popover.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Ensure the popover was closed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);
    });

    testWidgetsOnAllPlatforms('enforces the given popover geometry', (tester) async {
      final buttonKey = GlobalKey();
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PopoverScaffold(
                controller: popoverController,
                popoverGeometry: PopoverGeometry(
                  constraints: const BoxConstraints(maxHeight: 300),
                  align: (globalLeaderRect, followerSize, boundaryKey) => const FollowerAlignment(
                    leaderAnchor: Alignment.topRight,
                    followerAnchor: Alignment.topLeft,
                    followerOffset: Offset(10, 10),
                  ),
                ),
                buttonBuilder: (context) => SizedBox(key: buttonKey),
                popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                  child: SizedBox(height: 500),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      final buttonRect = tester.getRect(find.byKey(buttonKey));
      final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

      // Ensure the given geometry was honored.
      expect(popoverRect.height, 300);
      expect(popoverRect.top, buttonRect.top + 10);
      expect(popoverRect.left, buttonRect.right + 10);
    });

    testWidgetsOnAllPlatforms('shares focus with other widgets', (tester) async {
      final parentFocusNode = FocusNode();
      final popoverFocusNode = FocusNode();

      final popoverController = PopoverController();
      final overLayControler = OverlayPortalController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              focusNode: parentFocusNode,
              child: OverlayPortal(
                controller: overLayControler,
                overlayChildBuilder: (context) => PopoverScaffold(
                  controller: popoverController,
                  parentFocusNode: parentFocusNode,
                  popoverFocusNode: popoverFocusNode,
                  buttonBuilder: (context) => const SizedBox(),
                  popoverBuilder: (context) => Focus(
                    focusNode: popoverFocusNode,
                    child: const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Focus the parent node.
      parentFocusNode.requestFocus();
      await tester.pump();
      expect(parentFocusNode.hasPrimaryFocus, true);

      // Show the overlay.
      overLayControler.show();
      await tester.pumpAndSettle();

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the parent node has non-primary focus.
      expect(parentFocusNode.hasFocus, true);
      expect(parentFocusNode.hasPrimaryFocus, isFalse);

      // Close the popover.
      popoverController.close();
      await tester.pump();

      // Ensure the parent node has primary focus again.
      expect(parentFocusNode.hasPrimaryFocus, true);
    });
  });

  group('ItemSelectionList', () {
    testWidgetsOnAllPlatforms('changes active item down with DOWN ARROW', (tester) async {
      String? activeItem;

      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) => {},
        onItemActivated: (s) => activeItem = s,
      );

      // Ensure the popover is displayed without any active item.
      expect(activeItem, isNull);

      // Press DOWN ARROW to activate the first item.
      await tester.pressDownArrow();
      expect(activeItem, 'Item1');

      // Press DOWN ARROW to activate the second item.
      await tester.pressDownArrow();
      expect(activeItem, 'Item2');

      // Press DOWN ARROW to activate the third item.
      await tester.pressDownArrow();
      expect(activeItem, 'Item3');

      // Press DOWN ARROW to activate the first item again.
      await tester.pressDownArrow();
      expect(activeItem, 'Item1');
    });

    testWidgetsOnAllPlatforms('changes active item up with UP ARROW', (tester) async {
      String? activeItem;

      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) => {},
        onItemActivated: (s) => activeItem = s,
      );

      // Ensure the popover is displayed without any activate item.
      expect(activeItem, isNull);

      // Press UP ARROW to activate the last item.
      await tester.pressUpArrow();
      expect(activeItem, 'Item3');

      // Press UP ARROW to activate the second item.
      await tester.pressUpArrow();
      expect(activeItem, 'Item2');

      // Press UP ARROW to activate the first item.
      await tester.pressUpArrow();
      expect(activeItem, 'Item1');

      // Press UP ARROW to activate the last item again.
      await tester.pressUpArrow();
      expect(activeItem, 'Item3');
    });

    testWidgetsOnAllPlatforms('selects the active item on ENTER', (tester) async {
      String? selectedValue;

      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) => selectedValue = s,
      );

      // Press ARROW DOWN to activate the first item.
      await tester.pressDownArrow();

      // Press ENTER to select the active item.
      await tester.pressEnter();
      await tester.pump();

      // Ensure the first item was selected.
      expect(selectedValue, 'Item1');
    });

    testWidgetsOnAllPlatforms('clears selected item on ENTER without an active item', (tester) async {
      String? selectedValue = '';

      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) => selectedValue = s,
      );

      // Press ENTER without an active item.
      await tester.pressEnter();
      await tester.pump();

      // Ensure the selected item was set to null.
      expect(selectedValue, isNull);
    });

    testWidgetsOnAllPlatforms('calls onCancel on ESC', (tester) async {
      String? selectedValue;
      bool isCanceled = false;

      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) => selectedValue = s,
        onCancel: () => isCanceled = true,
      );

      // Press ARROW DOWN to activate the first item.
      await tester.pressDownArrow();

      // Press ESC to cancel.
      await tester.pressEscape();
      await tester.pump();

      // Ensure onCancel was called and no item was selected.
      expect(isCanceled, true);
      expect(selectedValue, isNull);
    });

    testWidgetsOnAllPlatforms('isn\'t scrollable if all items fit on screen', (tester) async {
      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) {},
      );

      // Ensure the list isn't scrollable.
      final dropdownButonState = tester.state<ItemSelectionListState<String>>(find.byType(ItemSelectionList<String>));
      expect(dropdownButonState.scrollController.position.maxScrollExtent, 0.0);
    });

    testWidgetsOnAllPlatforms('is scrollable if items don\'t fit on screen', (tester) async {
      await _pumpItemSelectionListTestApp(
        tester,
        onItemSelected: (s) {},
        constraints: const BoxConstraints(maxHeight: 50),
      );

      // Ensure the list is scrollable.
      final dropdownButonState = tester.state<ItemSelectionListState<String>>(find.byType(ItemSelectionList<String>));
      expect(dropdownButonState.scrollController.position.maxScrollExtent, greaterThan(0.0));
    });
  });
}

/// Pumps a widget tree with a [ItemSelectionList] containing three items and
/// immediately requests focus to it.
Future<void> _pumpItemSelectionListTestApp(
  WidgetTester tester, {
  required void Function(String? value) onItemSelected,
  void Function(String? value)? onItemActivated,
  VoidCallback? onCancel,
  BoxConstraints? constraints,
}) async {
  final focusNode = FocusNode();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: constraints ?? const BoxConstraints(),
          child: ItemSelectionList<String>(
            focusNode: focusNode,
            value: null,
            items: const ['Item1', 'Item2', 'Item3'],
            onItemSelected: onItemSelected,
            onItemActivated: onItemActivated,
            onCancel: onCancel,
            itemBuilder: (context, item, isActive, onTap) => TextButton(
              onPressed: onTap,
              child: Text(item),
            ),
          ),
        ),
      ),
    ),
  );

  focusNode.requestFocus();
  await tester.pump();
}

/// Displays a [SuperEditor] that fills the available height, containing a single paragraph,
/// and a [toolbar] at the bottom.
class _SuperEditorDropdownTestApp extends StatefulWidget {
  const _SuperEditorDropdownTestApp({
    required this.toolbar,
    this.editorFocusNode,
  });

  final FocusNode? editorFocusNode;
  final Widget toolbar;

  @override
  State<_SuperEditorDropdownTestApp> createState() => _SuperEditorDropdownTestAppState();
}

class _SuperEditorDropdownTestAppState extends State<_SuperEditorDropdownTestApp> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = singleParagraphDoc();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    _docEditor.dispose();
    _doc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SuperEditor(
              document: _doc,
              editor: _docEditor,
              composer: _composer,
              inputSource: TextInputSource.ime,
              focusNode: widget.editorFocusNode,
            ),
          ),
          widget.toolbar,
        ],
      ),
    );
  }
}
