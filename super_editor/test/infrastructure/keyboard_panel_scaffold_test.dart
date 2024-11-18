import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../super_editor/supereditor_test_tools.dart';

void main() {
  group('Keyboard panel scaffold >', () {
    group('phones >', () {
      testWidgetsOnMobilePhone('does not show toolbar upon initialization when IME is disconnected', (tester) async {
        await _pumpTestApp(tester);

        // Ensure the toolbar isn't visible.
        expect(find.byKey(_aboveKeyboardToolbarKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows toolbar at the bottom when there is no keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Ensure the above-keyboard toolbar sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height),
        );
      });

      testWidgetsOnMobilePhone('shows keyboard toolbar above the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the above-keyboard panel sits above the software keyboard.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone(
        'shows keyboard toolbar above the keyboard when toggling panels and showing the keyboard',
        (tester) async {
          final softwareKeyboardController = SoftwareKeyboardController();
          final controller = KeyboardPanelController(softwareKeyboardController);

          await _pumpTestApp(
            tester,
            controller: controller,
            softwareKeyboardController: softwareKeyboardController,
          );

          // Request to show the above-keyboard panel.
          controller.showToolbar();
          await tester.pump();

          // Place the caret at the beginning of the document to show the software keyboard.
          await tester.placeCaretInParagraph('1', 0);

          // Request to show the keyboard panel.
          controller.showKeyboardPanel();
          await tester.pumpAndSettle();

          // Hide both the keyboard panel and the software keyboard.
          controller.closeKeyboardAndPanel();
          await tester.pumpAndSettle();

          // Place the caret at the beginning of the document to show the software keyboard again.
          await tester.placeCaretInParagraph('1', 0);

          // Ensure the top panel sits above the keyboard.
          expect(
            tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
            equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
          );
        },
      );

      testWidgetsOnMobilePhone('does not show keyboard panel upon keyboard appearance', (tester) async {
        await _pumpTestApp(tester);

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows keyboard panel upon request', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);
      });

      testWidgetsOnMobilePhone('displays panel with the same height as the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel has the same size as the software keyboard.
        expect(
          tester.getSize(find.byKey(_keyboardPanelKey)).height,
          equals(_expandedPhoneKeyboardHeight),
        );

        // Ensure the above-keyboard panel sits immediately above the keyboard panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone('hides the panel when toggling the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Hide the keyboard panel and show the software keyboard.
        controller.toggleSoftwareKeyboardWithPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the above-keyboard panel sits immediately above the keyboard.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height - _expandedPhoneKeyboardHeight),
        );
      });

      testWidgetsOnMobilePhone('hides the panel upon request', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard panel.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        controller.closeKeyboardAndPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the above-keyboard panel sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          equals(tester.getSize(find.byType(MaterialApp)).height),
        );
      });

      testWidgetsOnMobilePhone('hides the panel when IME connection closes', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to open the IME connection.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Close the IME connection.
        softwareKeyboardController.close();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);
      });

      testWidgetsOnMobilePhone('shows toolbar at the bottom after closing the panel and the keyboard', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
        );

        // Request to show the above-keyboard toolbar.
        controller.showToolbar();
        await tester.pump();

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        // Hide the keyboard panel and the software keyboard.
        controller.closeKeyboardAndPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is not visible.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the above-keyboard toolbar sits at the bottom of the screen.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          tester.getSize(find.byType(MaterialApp)).height,
        );
      });
    });

    group('iPad >', () {
      testWidgetsOnIPad('shows panel when keyboard is docked', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedIPadKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _expandedIPadKeyboardHeight);
      });

      testWidgetsOnIPad('shows and closes panel when keyboard is floating or minimized', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _minimizedIPadKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the toolbar is above the minimized keyboard area.
        final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedIPadKeyboardHeight,
        );

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible and positioned at the bottom of the screen.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _keyboardPanelHeight);

        expect(
          tester.getBottomLeft(find.byKey(_keyboardPanelKey)).dy,
          screenHeight,
        );

        // Ensure the toolbar is above the panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _keyboardPanelHeight,
        );

        // Request to hide the keyboard panel.
        controller.hideKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is gone.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the toolbar is above the minimized keyboard area.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedIPadKeyboardHeight,
        );
      });
    });

    group('Android tablets >', () {
      testWidgetsOnAndroidTablet('shows panel when keyboard is docked', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedAndroidTabletKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _expandedAndroidTabletKeyboardHeight);
      });

      testWidgetsOnAndroidTablet('shows panel when keyboard is floating or minimized', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _minimizedAndroidTabletKeyboardHeight,
        );

        // Place the caret at the beginning of the document to show the software keyboard.
        await tester.placeCaretInParagraph('1', 0);

        // Ensure the toolbar is above the minimized keyboard area.
        final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedAndroidTabletKeyboardHeight,
        );

        // Request to show the keyboard panel and let the entrance animation run.
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is visible and positioned at the bottom of the screen.
        expect(find.byKey(_keyboardPanelKey), findsOneWidget);

        final panelSize = tester.getSize(find.byKey(_keyboardPanelKey));
        expect(panelSize.height, _keyboardPanelHeight);

        expect(
          tester.getBottomLeft(find.byKey(_keyboardPanelKey)).dy,
          screenHeight,
        );

        // Ensure the toolbar is above the panel.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _keyboardPanelHeight,
        );

        // Request to hide the keyboard panel.
        controller.hideKeyboardPanel();
        await tester.pumpAndSettle();

        // Ensure the keyboard panel is gone.
        expect(find.byKey(_keyboardPanelKey), findsNothing);

        // Ensure the toolbar is above the minimized keyboard area.
        expect(
          tester.getBottomLeft(find.byKey(_aboveKeyboardToolbarKey)).dy,
          screenHeight - _minimizedAndroidTabletKeyboardHeight,
        );
      });
    });

    group('safe area >', () {
      testWidgetsOnMobilePhone('makes room for keyboard panel', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedPhoneKeyboardHeight,
        );

        // Record the height of the content when no keyboard or panel is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show a keyboard panel (not the keyboard).
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Record the height of the content now that a keyboard panel is open.
        final contentHeightWithKeyboardPanelOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard panel.
        expect(contentHeightWithNoKeyboard - contentHeightWithKeyboardPanelOpen, _keyboardPanelHeight);
      });

      testWidgetsOnMobilePhone('removes bottom insets when focus leaves editor', (tester) async {
        final softwareKeyboardController = SoftwareKeyboardController();
        final controller = KeyboardPanelController(softwareKeyboardController);

        await _pumpTestApp(
          tester,
          controller: controller,
          softwareKeyboardController: softwareKeyboardController,
          simulatedKeyboardHeight: _expandedPhoneKeyboardHeight,
        );

        // Record the height of the content when no keyboard or panel is open.
        final contentHeightWithNoKeyboard = tester.getSize(find.byKey(_chatPageKey)).height;

        // Show a keyboard panel (not the keyboard).
        controller.showKeyboardPanel();
        await tester.pumpAndSettle();

        // Record the height of the content now that a keyboard panel is open.
        final contentHeightWithKeyboardPanelOpen = tester.getSize(find.byKey(_chatPageKey)).height;

        // Ensure that the content is pushed up above the keyboard panel.
        expect(contentHeightWithNoKeyboard - contentHeightWithKeyboardPanelOpen, _keyboardPanelHeight);

        // Switch to other tab.
        await tester.tap(find.byKey(_accountTabKey));
        await tester.pumpAndSettle();

        // Ensure the chat page is gone.
        expect(find.byKey(_chatPageKey), findsNothing);

        // Ensure that the account tab's content is full height (isn't restricted by safe area).
        expect(tester.getSize(find.byKey(_accountPageKey)).height, contentHeightWithNoKeyboard);
      });
    });
  });
}

/// Pumps a tree that displays a panel at the software keyboard position.
///
/// Simulates the software keyboard appearance and disappearance by animating
/// the `MediaQuery` view insets when the app communicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestApp(
  WidgetTester tester, {
  KeyboardPanelController? controller,
  SoftwareKeyboardController? softwareKeyboardController,
  ValueNotifier<bool>? isImeConnected,
  double simulatedKeyboardHeight = _expandedPhoneKeyboardHeight,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final keyboardPanelController = controller ?? KeyboardPanelController(keyboardController);
  final imeConnectionNotifier = isImeConnected ?? ValueNotifier<bool>(false);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withImeConnectionNotifier(imeConnectionNotifier)
      .simulateSoftwareKeyboardInsets(
        true,
        simulatedKeyboardHeight: simulatedKeyboardHeight,
      )
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(
                      key: _chatTabKey,
                      icon: Icon(Icons.chat),
                    ),
                    Tab(
                      key: _accountTabKey,
                      icon: Icon(Icons.account_circle),
                    ),
                  ],
                ),
              ),
              resizeToAvoidBottomInset: false,
              body: KeyboardScaffoldSafeArea(
                // ^ This safe area is needed to receive the bottom insets from the
                //   bottom mounted editor, and then make it available to the subtree
                //   with the content behind the chat.
                //
                //   Also, by including 2 of these safe areas in the same tree, we implicitly
                //   verify that multiple safe areas in the same tree work together.
                child: TabBarView(children: [
                  // ^ We build a tab view so that we can test what happens when the editor
                  //   has focus and a keyboard panel is up, and then the user navigates to
                  //   another tab, which should remove the bottom safe area when it happens.
                  _buildChatPage(
                    keyboardPanelController,
                    imeConnectionNotifier,
                    superEditor,
                  ),
                  _buildAccountPage(),
                ]),
              ),
            ),
          ),
        ),
      )
      .pump();
}

Widget _buildChatPage(
  KeyboardPanelController keyboardPanelController,
  ValueNotifier<bool> imeConnectionNotifier,
  Widget superEditor,
) {
  return Stack(
    children: [
      // An area that simulates content that sits underneath
      // a bottom mounted chat editor.
      Positioned.fill(
        child: KeyboardScaffoldSafeArea(
          child: Container(
            key: _chatPageKey,
            color: Colors.blue,
          ),
        ),
      ),

      // An area that simulates a bottom mounted chat editor.
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 200,
        child: Builder(builder: (context) {
          return KeyboardPanelScaffold(
            controller: keyboardPanelController,
            isImeConnected: imeConnectionNotifier,
            contentBuilder: (context, isKeyboardPanelVisible) => superEditor,
            toolbarBuilder: (context, isKeyboardPanelVisible) => Container(
              key: _aboveKeyboardToolbarKey,
              height: 54,
              color: Colors.blue,
            ),
            fallbackPanelHeight: _keyboardPanelHeight,
            keyboardPanelBuilder: (context) => const SizedBox.expand(
              child: ColoredBox(
                key: _keyboardPanelKey,
                color: Colors.red,
              ),
            ),
          );
        }),
      ),
    ],
  );
}

Widget _buildAccountPage() {
  return ColoredBox(
    key: _accountPageKey,
    color: Colors.grey.shade100,
    child: const Center(
      child: Icon(Icons.account_circle),
    ),
  );
}

const _chatTabKey = ValueKey("chat_tab_button");
const _chatPageKey = ValueKey("chat_content");

const _accountTabKey = ValueKey("account_tab_button");
const _accountPageKey = ValueKey("account_content");

void testWidgetsOnMobilePhone(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMobile(
    description,
    (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1179, 2556)
        ..devicePixelRatio = 3.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

// TODO: we want the iPad and Android tablet to be configurable in some way for
//       minimized/floating keyboard vs docked keyboard.

void testWidgetsOnIPad(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnIos(
    description,
    (WidgetTester tester) async {
      tester.view
        // Simulate an iPad Pro 12
        ..physicalSize = const Size(2048, 2732)
        ..devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

void testWidgetsOnAndroidTablet(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnAndroid(
    description,
    (WidgetTester tester) async {
      tester.view
        // Simulate a Pixel tablet.
        ..physicalSize = const Size(1600, 2560)
        ..devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.reset();
      });

      await test(tester);
    },
    skip: skip,
    variant: variant,
  );
}

// Simulated height of a fully visible phone keyboard. We specify this because
// there's no real window in a widget test, and therefore no real keyboard.
const _expandedPhoneKeyboardHeight = 300.0;

// Arbitrary height used to display keyboard panels in place of the keyboard. These
// panels are controlled entirely by the KeyboardScaffold in the app, so the height can
// be whatever is desired. Ideally, apps would make these the same height as the keyboard,
// but we specify a value that's different from the simulated keyboard so that we can
// verify heights without accidentally confusing the keyboard and panel heights.
const _keyboardPanelHeight = 275.0;

const _expandedIPadKeyboardHeight = 300.0;
// iPad can show a "minimized" keyboard, which takes up a short area at
// the bottom of the screen, and within that short area is a small
// toolbar that shows spelling suggestions along with a button that
// opens a keyboard options menu.
const _minimizedIPadKeyboardHeight = 69.0;

const _expandedAndroidTabletKeyboardHeight = 300.0;
// Android tablets can show a "minimized" keyboard, which takes up a
// short area at the bottom of the screen, and within that short area
// is a small toolbar that includes delete, emojis, audio recording, and
// a button to open a menu.
const _minimizedAndroidTabletKeyboardHeight = 62.0;

const _aboveKeyboardToolbarKey = ValueKey('toolbar');
const _keyboardPanelKey = ValueKey('keyboardPanel');
