import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/default_document_editor.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/super_reader/super_reader.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/src/test/super_reader_test/super_reader_robot.dart';

import 'test_documents.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnAllPlatforms('can be switched with a SuperReader', (tester) async {
      final isEditable = ValueNotifier<bool>(true);
      final document = longDoc();
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: _EditorReaderSwitchDemo(
            document: document,
            isEditable: isEditable,
            scrollController: scrollController,
          ),
        ),
      );

      // Select the first word and scroll the viewport an arbitrary amount of pixels.
      await SuperEditorRobot(tester).doubleTapInParagraph('1', 0);
      scrollController.jumpTo(100.0);
      await tester.pump();

      // Switch the SuperEditor with a SuperReader.
      isEditable.value = false;
      await tester.pump();

      // Select the first word and scroll the viewport an arbitrary amount of pixels.
      await SuperReaderRobot(tester).doubleTapInParagraph('1', 0);
      scrollController.jumpTo(150.0);
      await tester.pump();

      // Switch back to the editor.
      isEditable.value = true;
      await tester.pump();

      // Select the first word and scroll the viewport an arbitrary amount of pixels.
      await SuperEditorRobot(tester).doubleTapInParagraph('1', 0);
      scrollController.jumpTo(200.0);
      await tester.pump();

      // Reaching this point means we switched between SuperEditor and SuperReader without any crashes.
    });
  });
}

/// A Scaffold which switches between a [SuperEditor] and a [SuperEditor] depending
/// on the value of [isEditable].
class _EditorReaderSwitchDemo extends StatefulWidget {
  const _EditorReaderSwitchDemo({
    Key? key,
    required this.isEditable,
    required this.document,
    required this.scrollController,
  }) : super(key: key);

  final MutableDocument document;

  /// When `true` a [SuperEditor] is displayed. Otherwise, display a [SuperReader].
  final ValueListenable<bool> isEditable;

  /// Scroll controller of the viewport.
  final ScrollController scrollController;

  @override
  State<_EditorReaderSwitchDemo> createState() => _EditorReaderSwitchDemoState();
}

class _EditorReaderSwitchDemoState extends State<_EditorReaderSwitchDemo> {
  late Editor _docEditor;
  late MutableDocumentComposer _composer;

  @override
  void initState() {
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(
      document: widget.document,
      composer: _composer,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          const SliverAppBar(),
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: widget.isEditable,
              builder: (context, _) {
                return _buildEditorOrReader();
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEditorOrReader() {
    if (widget.isEditable.value) {
      return SuperEditor(
        editor: _docEditor,
      );
    } else {
      return SuperReader(
        document: widget.document,
      );
    }
  }
}
