import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../supereditor_test_tools.dart';

Future<void> main() async {
  // Replace the default test binding with our fake so we can override the
  // keyboard modifier state.
  //
  // This affects all the tests in this file, and can't be reset, so only tests
  // that use this binding are in this test file.
  final FakeServicesBinding binding = FakeServicesBinding();

  group('text.dart', () {
    group('TextComposable text entry', () {
      test('it does nothing when meta is pressed', () {
        // Make sure we're using our fake binding so we can override keyboard
        // modifier state.
        assert(ServicesBinding.instance == binding);
        final editContext = _createEditContext();

        // Press just the meta key.
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.meta,
            physicalKey: PhysicalKeyboardKey.metaLeft,
            timeStamp: Duration.zero,
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);

        // Press "a" + meta key
        binding.fakeKeyboard.isMetaPressed = true;
        expect(HardwareKeyboard.instance.isMetaPressed, isTrue);
        result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.keyA,
            physicalKey: PhysicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        );

        binding.fakeKeyboard.isMetaPressed = false;
        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });
    });
  });
}

SuperEditorContext _createEditContext() {
  final document = MutableDocument();
  final composer = MutableDocumentComposer();
  final documentEditor = createDefaultDocumentEditor(document: document, composer: composer);
  final fakeLayout = FakeDocumentLayout();
  return SuperEditorContext(
    editor: documentEditor,
    document: document,
    getDocumentLayout: () => fakeLayout,
    composer: composer,
    scroller: FakeSuperEditorScroller(),
    commonOps: CommonEditorOperations(
      editor: documentEditor,
      document: document,
      composer: composer,
      documentLayoutResolver: () => fakeLayout,
    ),
  );
}

class FakeServicesBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void initInstances() {
    fakeKeyboard = FakeHardwareKeyboard();
    super.initInstances();
  }

  late final FakeHardwareKeyboard fakeKeyboard;

  @override
  HardwareKeyboard get keyboard => fakeKeyboard;
}

class FakeHardwareKeyboard extends HardwareKeyboard {
  FakeHardwareKeyboard({
    this.isAltPressed = false,
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
  });

  @override
  bool isMetaPressed;
  @override
  bool isControlPressed;
  @override
  bool isAltPressed;
  @override
  bool isShiftPressed;

  @override
  bool isLogicalKeyPressed(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.shift || LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => isShiftPressed,
      LogicalKeyboardKey.alt || LogicalKeyboardKey.altLeft || LogicalKeyboardKey.altRight => isAltPressed,
      LogicalKeyboardKey.control || LogicalKeyboardKey.controlLeft || LogicalKeyboardKey.controlRight => isControlPressed,
      LogicalKeyboardKey.meta || LogicalKeyboardKey.metaLeft || LogicalKeyboardKey.metaRight => isMetaPressed,
      _ => super.isLogicalKeyPressed(key)
    };
  }
}
