import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/selectable_list.dart';

void main() {
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
