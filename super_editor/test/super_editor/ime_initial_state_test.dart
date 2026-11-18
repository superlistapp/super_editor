import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/document_ime/shared_ime.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  const platform = TargetPlatformVariant({TargetPlatform.iOS});
  testWidgets('text field sends initial state before showing keyboard', (tester) async {
    final focus = FocusNode();
    final controller = AttributedTextEditingController(
      text: AttributedText('Synthetic title'),
      selection: const TextSelection.collapsed(offset: 4),
      composingRegion: const TextRange(start: 0, end: 4),
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SuperTextField(
      focusNode: focus,
      textController: controller,
      inputSource: TextInputSource.ime,
    ))));
    tester.testTextInput.log.clear();
    focus.requestFocus();
    await tester.pump();
    final calls = tester.testTextInput.log;
    final stateIndex = calls.indexWhere((c) => c.method == 'TextInput.setEditingState');
    final showIndex = calls.indexWhere((c) => c.method == 'TextInput.show');
    expect(stateIndex, greaterThanOrEqualTo(0));
    expect(showIndex, greaterThan(stateIndex), reason: calls.map((c) => c.method).join(', '));
    expect(calls[stateIndex].arguments, containsPair('text', 'Synthetic title'));
    expect(calls[stateIndex].arguments, containsPair('selectionBase', 4));
    expect(calls[stateIndex].arguments, containsPair('composingExtent', 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    focus.dispose();
    controller.dispose();
  }, variant: platform);

  testWidgets('document sends initial state before showing keyboard', (tester) async {
    final focus = FocusNode();
    final document = MutableDocument(nodes: [ParagraphNode(id: 'p', text: AttributedText('Synthetic document'))]);
    final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
      position: DocumentPosition(nodeId: 'p', nodePosition: TextNodePosition(offset: 4)),
    ));
    final editor = createDefaultDocumentEditor(document: document, composer: composer);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SuperEditor(
      editor: editor,
      focusNode: focus,
      inputSource: TextInputSource.ime,
    ))));
    tester.testTextInput.log.clear();
    focus.requestFocus();
    await tester.pump();
    final calls = tester.testTextInput.log;
    final stateIndex = calls.indexWhere((c) => c.method == 'TextInput.setEditingState');
    final showIndex = calls.indexWhere((c) => c.method == 'TextInput.show');
    expect(stateIndex, greaterThanOrEqualTo(0));
    expect(showIndex, greaterThan(stateIndex), reason: calls.map((c) => c.method).join(', '));
    expect(calls[stateIndex].arguments, containsPair('text', '. Synthetic document'));
    expect(calls[stateIndex].arguments, containsPair('selectionBase', 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    focus.dispose();
  }, variant: platform);
  testWidgets('does not show an IME connection closed by its initialization listener', (tester) async {
    final ime = SuperIme.instance;
    final owner = SuperImeInputId(role: 'initial-state-test', instance: Object());
    final client = ImeAttributedTextEditingController();
    ime.takeOwnership(owner);
    void closeOnOpen() {
      if (ime.isInputAttachedToOS(owner)) {
        ime.clearConnection(owner);
      }
    }

    ime.addListener(closeOnOpen);
    addTearDown(() {
      ime.removeListener(closeOnOpen);
      ime.releaseOwnership(owner);
      client.dispose();
    });
    tester.testTextInput.log.clear();
    ime.openConnection(owner, client, const TextInputConfiguration(), showKeyboard: true);
    await tester.pump();
    expect(tester.testTextInput.log.where((c) => c.method == 'TextInput.show'), isEmpty);
    expect(ime.isAttachedToOS, isFalse);
  }, variant: platform);

  testWidgets('does not show an IME connection whose owner changes during initialization', (tester) async {
    final ime = SuperIme.instance;
    final owner = SuperImeInputId(role: 'old-owner', instance: Object());
    final replacement = SuperImeInputId(role: 'new-owner', instance: Object());
    final client = ImeAttributedTextEditingController();
    ime.takeOwnership(owner);
    void replaceOnOpen() {
      if (ime.isInputAttachedToOS(owner)) {
        ime.takeOwnership(replacement);
      }
    }

    ime.addListener(replaceOnOpen);
    addTearDown(() {
      ime.removeListener(replaceOnOpen);
      ime.releaseOwnership(replacement);
      ime.releaseOwnership(owner);
      client.dispose();
    });
    tester.testTextInput.log.clear();
    ime.openConnection(owner, client, const TextInputConfiguration(), showKeyboard: true);
    await tester.pump();
    expect(tester.testTextInput.log.where((c) => c.method == 'TextInput.show'), isEmpty);
    expect(ime.isOwner(replacement), isTrue);
  }, variant: platform);

  testWidgets('configuration replacement initializes state before showing keyboard', (tester) async {
    final controller = ImeAttributedTextEditingController(
      controller: AttributedTextEditingController(
        text: AttributedText('Replacement'),
        selection: const TextSelection.collapsed(offset: 3),
      ),
    );
    addTearDown(controller.dispose);
    controller.attachToImeWithConfig(const TextInputConfiguration());
    await tester.pump();
    tester.testTextInput.log.clear();
    controller.updateTextInputConfiguration(viewId: tester.view.viewId, textInputType: TextInputType.multiline);
    await tester.pump();
    final calls = tester.testTextInput.log;
    final stateIndex = calls.indexWhere((c) => c.method == 'TextInput.setEditingState');
    expect(stateIndex, greaterThanOrEqualTo(0));
    expect(calls.indexWhere((c) => c.method == 'TextInput.show'), greaterThan(stateIndex));
    expect(calls[stateIndex].arguments, containsPair('text', 'Replacement'));
    expect(calls[stateIndex].arguments, containsPair('selectionBase', 3));
    controller.detachFromIme();
    await tester.pump();
  }, variant: platform);

  testWidgets('text field does not show a connection detached by its listener', (tester) async {
    final controller = ImeAttributedTextEditingController();
    void detachOnAttach() {
      if (controller.isAttachedToIme) controller.detachFromIme();
    }

    controller.inputConnectionNotifier.addListener(detachOnAttach);
    addTearDown(() {
      controller.inputConnectionNotifier.removeListener(detachOnAttach);
      controller.dispose();
    });
    tester.testTextInput.log.clear();
    controller.attachToImeWithConfig(const TextInputConfiguration());
    await tester.pump();
    expect(controller.isAttachedToIme, isFalse);
    expect(tester.testTextInput.log.where((c) => c.method == 'TextInput.show'), isEmpty);
  }, variant: platform);
}
