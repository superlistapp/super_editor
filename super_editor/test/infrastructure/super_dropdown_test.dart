// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_test_robots/flutter_test_robots.dart';
// import 'package:flutter_test_runners/flutter_test_runners.dart';

// import 'package:super_editor/src/core/document.dart';
// import 'package:super_editor/src/core/document_composer.dart';
// import 'package:super_editor/src/core/document_selection.dart';
// import 'package:super_editor/src/core/editor.dart';
// import 'package:super_editor/src/default_editor/default_document_editor.dart';
// import 'package:super_editor/src/default_editor/super_editor.dart';
// import 'package:super_editor/src/default_editor/text.dart';
// import 'package:super_editor/src/infrastructure/dropdown.dart';
// import 'package:super_editor/src/infrastructure/text_input.dart';
// import 'package:super_editor/super_editor_test.dart';

// import '../super_editor/test_documents.dart';

// void main() {
//   group('SuperDropdown', () {
//     testWidgetsOnAllPlatforms('shows the dropdown list on tap', (tester) async {
//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) {},
//       );

//       // Ensures the dropdown list isn't displayed.
//       expect(find.byType(PopoverShape), findsNothing);

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);
//     });

//     testWidgetsOnAllPlatforms('calls onSelected and closes the dropdown list when tapping an item', (tester) async {
//       String? selectedValue;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => selectedValue = s,
//       );

//       // Ensures the dropdown list isn't displayed.
//       expect(find.byType(PopoverShape), findsNothing);

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);

//       // Taps the first item on the list
//       await tester.tap(find.text('Item1'));
//       await tester.pumpAndSettle();

//       // Ensure the tapped item was selected and the dropdown was closed.
//       expect(selectedValue, 'Item1');
//       expect(find.byType(PopoverShape), findsNothing);
//     });

//     testWidgetsOnAllPlatforms('closes the dropdown list when tapping outside', (tester) async {
//       bool onValueChangedCalled = false;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => onValueChangedCalled = true,
//       );

//       // Ensures the dropdown list isn't displayed.
//       expect(find.byType(PopoverShape), findsNothing);

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);

//       // Taps outside of the dropdown.
//       await tester.tapAt(Offset.zero);
//       await tester.pumpAndSettle();

//       // Ensures onValueChanged wasn't called and the dropdown list was closed.
//       expect(onValueChangedCalled, isFalse);
//       expect(find.byType(PopoverShape), findsNothing);
//     });

//     testWidgetsOnAllPlatforms('enforces the given dropdown constraints', (tester) async {
//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) {},
//         popoverGeometry: PopoverGeometry(
//           constraints: const BoxConstraints(maxHeight: 10),
//         ),
//       );

//       // Ensures the dropdown list isn't displayed.
//       expect(find.byType(PopoverShape), findsNothing);

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);

//       // Ensure the maxHeight was honored.
//       expect(tester.getRect(find.byType(PopoverShape)).height, 10);
//     });

//     testWidgetsOnAllPlatforms('dropdown list isn\' scrollable if all items fit on screen', (tester) async {
//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) {},
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);

//       // Ensure the dropdown list isn't scrollable.
//       final dropdownButonState = tester.state<ItemSelectionListState<String>>(find.byType(ItemSelectionList<String>));
//       expect(dropdownButonState.scrollController.position.maxScrollExtent, 0.0);
//     });

//     testWidgetsOnAllPlatforms('dropdown list is scrollable if items don\'t fit on screen', (tester) async {
//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) {},
//         popoverGeometry: PopoverGeometry(constraints: const BoxConstraints(maxHeight: 50)),
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensures the dropdown list is displayed.
//       expect(find.byType(PopoverShape), findsOneWidget);

//       // Ensure the dropdown list is scrollable.
//       final dropdownButonState = tester.state<ItemSelectionListState<String>>(find.byType(ItemSelectionList<String>));
//       expect(dropdownButonState.scrollController.position.maxScrollExtent, greaterThan(0.0));
//     });

//     testWidgetsOnAllPlatforms('moves focus down with DOWN ARROW', (tester) async {
//       String? activeItem;
//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => {},
//         onActivate: (s) => activeItem = s,
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensure the dropdown is displayed without any focused item.
//       expect(activeItem, isNull);

//       // Press DOWN ARROW to focus the first item.
//       await tester.pressDownArrow();
//       expect(activeItem, 'Item1');

//       // Press DOWN ARROW to focus the second item.
//       await tester.pressDownArrow();
//       expect(activeItem, 'Item2');

//       // Press DOWN ARROW to focus the third item.
//       await tester.pressDownArrow();
//       expect(activeItem, 'Item3');

//       // Press DOWN ARROW to focus the first item again.
//       await tester.pressDownArrow();
//       expect(activeItem, 'Item1');
//     });

//     testWidgetsOnAllPlatforms('moves focus up with UP ARROW', (tester) async {
//       String? activeItem;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => {},
//         onActivate: (s) => activeItem = s,
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensure the dropdown is displayed without any focused item.
//       expect(activeItem, isNull);

//       // Press UP ARROW to focus the last item.
//       await tester.pressUpArrow();
//       expect(activeItem, 'Item3');

//       // Press UP ARROW to focus the second item.
//       await tester.pressUpArrow();
//       expect(activeItem, 'Item2');

//       // Press UP ARROW to focus the first item.
//       await tester.pressUpArrow();
//       expect(activeItem, 'Item1');

//       // Press UP ARROW to focus the last item again.
//       await tester.pressUpArrow();
//       expect(activeItem, 'Item3');
//     });

//     testWidgetsOnAllPlatforms('selects the focused item on ENTER', (tester) async {
//       String? selectedValue;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => selectedValue = s,
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Press ARROW DOWN to focus the first item.
//       await tester.pressDownArrow();

//       // Press ENTER to select the focused item and close the dropdown.
//       await tester.pressEnter();
//       await tester.pump();

//       // Ensure the first item was selected and the dropdown was closed.
//       expect(selectedValue, 'Item1');
//       expect(find.byType(PopoverShape), findsNothing);
//     });

//     testWidgetsOnAllPlatforms('closes dropdown list on ENTER', (tester) async {
//       String? selectedValue;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => selectedValue = s,
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Press ENTER without a focused item to close the dropdown.
//       await tester.pressEnter();
//       await tester.pump();

//       // Ensure the dropdown was closed and no item was selected.
//       expect(find.byType(PopoverShape), findsNothing);
//       expect(selectedValue, isNull);
//     });

//     testWidgetsOnAllPlatforms('closes dropdown list on ESC', (tester) async {
//       String? selectedValue;

//       await _pumpDropdownTestApp(
//         tester,
//         onValueChanged: (s) => selectedValue = s,
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Press ARROW DOWN to focus the first item.
//       await tester.pressDownArrow();

//       // Press ESC to close the dropdown.
//       await tester.pressEscape();
//       await tester.pump();

//       // Ensure the dropdown was closed and no item was selected.
//       expect(find.byType(PopoverShape), findsNothing);
//       expect(selectedValue, isNull);
//     });

//     testWidgetsOnAllPlatforms('shares focus with SuperEditor', (tester) async {
//       final editorFocusNode = FocusNode();
//       final boundaryKey = GlobalKey();

//       await tester.pumpWidget(
//         MaterialApp(
//           key: boundaryKey,
//           home: _SuperEditorDropdownTestApp(
//             editorFocusNode: editorFocusNode,
//             toolbar: ConstrainedBox(
//               constraints: const BoxConstraints(maxHeight: 100),
//               child: ItemSelectionList<String>(
//                 items: const ['Item1', 'Item2', 'Item3'],
//                 itemBuilder: (context, e, isActive, onTap) => TextButton(
//                   onPressed: onTap,
//                   child: Text(e),
//                 ),
//                 buttonBuilder: (context, e, onTap) => ElevatedButton(
//                   onPressed: onTap,
//                   child: const SizedBox(width: 50),
//                 ),
//                 value: null,
//                 onItemSelected: (s) => {},
//                 boundaryKey: boundaryKey,
//                 parentFocusNode: editorFocusNode,
//               ),
//             ),
//           ),
//         ),
//       );

//       final documentNode = SuperEditorInspector.findDocument()!.nodes.first;

//       // Double tap to select the word "Lorem".
//       await tester.doubleTapInParagraph(documentNode.id, 1);

//       // Ensure the editor has primary focus and the word "Lorem" is selected.
//       expect(editorFocusNode.hasPrimaryFocus, isTrue);
//       expect(
//         SuperEditorInspector.findDocumentSelection(),
//         DocumentSelection(
//           base: DocumentPosition(
//             nodeId: documentNode.id,
//             nodePosition: const TextNodePosition(offset: 0),
//           ),
//           extent: DocumentPosition(
//             nodeId: documentNode.id,
//             nodePosition: const TextNodePosition(offset: 5),
//           ),
//         ),
//       );

//       // Tap the button to show the dropdown.
//       await tester.tap(find.byType(ItemSelectionList<String>));
//       await tester.pumpAndSettle();

//       // Ensure the editor has non-primary focus.
//       expect(editorFocusNode.hasFocus, true);
//       expect(editorFocusNode.hasPrimaryFocus, isFalse);

//       // Tap at a dropdown list option to close the dropdown.
//       await tester.tap(find.text('Item2'));
//       await tester.pumpAndSettle();

//       // Ensure the editor has primary focus again and selection stays the same.
//       expect(editorFocusNode.hasPrimaryFocus, isTrue);
//       expect(
//         SuperEditorInspector.findDocumentSelection(),
//         DocumentSelection(
//           base: DocumentPosition(
//             nodeId: documentNode.id,
//             nodePosition: const TextNodePosition(offset: 0),
//           ),
//           extent: DocumentPosition(
//             nodeId: documentNode.id,
//             nodePosition: const TextNodePosition(offset: 5),
//           ),
//         ),
//       );
//     });
//   });
// }

// /// Pumps a widget tree with a centered [ItemSelectionList] containing three items.
// Future<void> _pumpDropdownTestApp(
//   WidgetTester tester, {
//   required void Function(String? value) onValueChanged,
//   void Function(String? value)? onActivate,
//   PopoverGeometry? popoverGeometry,
// }) async {
//   final boundaryKey = GlobalKey();
//   final focusNode = FocusNode();

//   await tester.pumpWidget(
//     MaterialApp(
//       key: boundaryKey,
//       home: Scaffold(
//         body: Center(
//           child: Focus(
//             focusNode: focusNode,
//             autofocus: true,
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxHeight: 100),
//               child: ItemSelectionList<String>(
//                 items: const ['Item1', 'Item2', 'Item3'],
//                 itemBuilder: (context, e, isActive, onTap) => TextButton(
//                   onPressed: onTap,
//                   child: Text(e),
//                 ),
//                 buttonBuilder: (context, e, onTap) => ElevatedButton(
//                   onPressed: onTap,
//                   child: const SizedBox(width: 50),
//                 ),
//                 value: null,
//                 onItemActivated: onActivate,
//                 onItemSelected: onValueChanged,
//                 boundaryKey: boundaryKey,
//                 parentFocusNode: focusNode,
//                 popoverGeometry: popoverGeometry,
//               ),
//             ),
//           ),
//         ),
//       ),
//     ),
//   );
// }

// /// Displays a [SuperEditor] that fills the available height, containing a single paragraph,
// /// and a [toolbar] at the bottom.
// class _SuperEditorDropdownTestApp extends StatefulWidget {
//   const _SuperEditorDropdownTestApp({
//     required this.toolbar,
//     this.editorFocusNode,
//   });

//   final FocusNode? editorFocusNode;
//   final Widget toolbar;

//   @override
//   State<_SuperEditorDropdownTestApp> createState() => _SuperEditorDropdownTestAppState();
// }

// class _SuperEditorDropdownTestAppState extends State<_SuperEditorDropdownTestApp> {
//   late MutableDocument _doc;
//   late MutableDocumentComposer _composer;
//   late Editor _docEditor;

//   @override
//   void initState() {
//     super.initState();
//     _doc = singleParagraphDoc();
//     _composer = MutableDocumentComposer();
//     _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
//   }

//   @override
//   void dispose() {
//     _docEditor.dispose();
//     _doc.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: [
//           Expanded(
//             child: SuperEditor(
//               document: _doc,
//               editor: _docEditor,
//               composer: _composer,
//               inputSource: TextInputSource.ime,
//               focusNode: widget.editorFocusNode,
//             ),
//           ),
//           widget.toolbar,
//         ],
//       ),
//     );
//   }
// }
