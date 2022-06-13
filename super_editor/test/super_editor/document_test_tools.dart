import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:text_table/text_table.dart';

import 'test_documents.dart';
import 'supereditor_inspector.dart';

/// Extensions on [WidgetTester] that configure and pump [SuperEditor]
/// document editors.
extension DocumentTester on WidgetTester {
  /// Starts the process for configuring and pumping a new [SuperEditor].
  ///
  /// Use the returned [TestDocumentSelector] to continue configuring the
  /// [SuperEditor].
  TestDocumentSelector createDocument() {
    return TestDocumentSelector(this);
  }

  /// Pumps a new [SuperEditor] using the existing [context].
  ///
  /// Use this method to simulate a [SuperEditor] whose widget tree changes.
  TestDocumentConfigurator updateDocument(TestDocumentContext context) {
    return TestDocumentConfigurator._fromExistingContext(this, context);
  }
}

/// Selects a [Document] configuration when composing a [SuperEditor]
/// widget in a test.
///
/// Each document selection returns a [TestDocumentConfigurator], which
/// is used to complete the configuration, and to pump the [SuperEditor].
class TestDocumentSelector {
  const TestDocumentSelector(this._widgetTester);

  final WidgetTester _widgetTester;

  TestDocumentConfigurator withCustomContent(MutableDocument document) {
    return TestDocumentConfigurator._(_widgetTester, document);
  }

  TestDocumentConfigurator withSingleEmptyParagraph() {
    return TestDocumentConfigurator._(
      _widgetTester,
      singleParagraphEmptyDoc(),
    );
  }

  TestDocumentConfigurator withSingleParagraph() {
    return TestDocumentConfigurator._(
      _widgetTester,
      singleParagraphDoc(),
    );
  }

  TestDocumentConfigurator withTwoEmptyParagraphs() {
    return TestDocumentConfigurator._(
      _widgetTester,
      twoParagraphEmptyDoc(),
    );
  }
}

/// Builder that configures and pumps a [SuperEditor] widget.
class TestDocumentConfigurator {
  TestDocumentConfigurator._fromExistingContext(this._widgetTester, this._existingContext) : _document = null;

  TestDocumentConfigurator._(this._widgetTester, this._document) : _existingContext = null;

  final WidgetTester _widgetTester;
  final MutableDocument? _document;
  final TestDocumentContext? _existingContext;
  DocumentGestureMode? _gestureMode;
  DocumentInputSource? _inputSource;
  Stylesheet? _stylesheet;
  bool _autoFocus = false;

  /// Configures the [SuperEditor] for standard desktop interactions,
  /// e.g., mouse and keyboard input.
  TestDocumentConfigurator forDesktop({
    DocumentInputSource inputSource = DocumentInputSource.keyboard,
  }) {
    _inputSource = inputSource;
    _gestureMode = DocumentGestureMode.mouse;
    return this;
  }

  /// Configures the [SuperEditor] for standard Android interactions,
  /// e.g., touch gestures and IME input.
  TestDocumentConfigurator forAndroid() {
    _gestureMode = DocumentGestureMode.android;
    _inputSource = DocumentInputSource.ime;
    return this;
  }

  /// Configures the [SuperEditor] for standard iOS interactions,
  /// e.g., touch gestures and IME input.
  TestDocumentConfigurator forIOS() {
    _gestureMode = DocumentGestureMode.iOS;
    _inputSource = DocumentInputSource.ime;
    return this;
  }

  /// Configures the [SuperEditor] to use the given [inputSource].
  TestDocumentConfigurator withInputSource(DocumentInputSource inputSource) {
    _inputSource = inputSource;
    return this;
  }

  /// Configures the [SuperEditor] to use the given [gestureMode].
  TestDocumentConfigurator withGestureMode(DocumentGestureMode gestureMode) {
    _gestureMode = gestureMode;
    return this;
  }

  DocumentGestureMode get _defaultGestureMode {
    switch (debugDefaultTargetPlatformOverride) {
      case TargetPlatform.android:
        return DocumentGestureMode.android;
      case TargetPlatform.iOS:
        return DocumentGestureMode.iOS;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return DocumentGestureMode.mouse;
      default:
        return DocumentGestureMode.mouse;
    }
  }

  DocumentInputSource get _defaultInputSource {
    switch (debugDefaultTargetPlatformOverride) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return DocumentInputSource.ime;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return DocumentInputSource.keyboard;
      default:
        return DocumentInputSource.keyboard;
    }
  }

  /// Configures the [SuperEditor] to use the given [stylesheet].
  TestDocumentConfigurator useStylesheet(Stylesheet stylesheet) {
    _stylesheet = stylesheet;
    return this;
  }

  /// Configures the [SuperEditor] to auto-focus when first pumped, or not.
  TestDocumentConfigurator autoFocus(bool autoFocus) {
    _autoFocus = autoFocus;
    return this;
  }

  /// Pumps a [SuperEditor] widget tree with the desired configuration, and returns
  /// a [TestDocumentContext], which includes the artifacts connected to the widget
  /// tree, e.g., the [DocumentEditor], [DocumentComposer], etc.
  Future<TestDocumentContext> pump() async {
    assert(_document != null || _existingContext != null);

    late TestDocumentContext testDocumentContext;
    if (_document != null) {
      final layoutKey = GlobalKey();
      final focusNode = FocusNode();
      final editor = DocumentEditor(document: _document!);
      final composer = DocumentComposer();
      // ignore: prefer_function_declarations_over_variables
      final layoutResolver = () => layoutKey.currentState as DocumentLayout;
      final commonOps = CommonEditorOperations(
        editor: editor,
        documentLayoutResolver: layoutResolver,
        composer: composer,
      );
      final editContext = EditContext(
        editor: editor,
        getDocumentLayout: layoutResolver,
        composer: composer,
        commonOps: commonOps,
      );

      testDocumentContext = TestDocumentContext._(
        focusNode: focusNode,
        layoutKey: layoutKey,
        editContext: editContext,
      );
    } else {
      testDocumentContext = _existingContext!;
    }

    await _widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          documentLayoutKey: testDocumentContext.layoutKey,
          editor: testDocumentContext.editContext.editor,
          focusNode: testDocumentContext.focusNode,
          inputSource: _inputSource ?? _defaultInputSource,
          gestureMode: _gestureMode ?? _defaultGestureMode,
          stylesheet: _stylesheet,
          autofocus: _autoFocus,
        ),
      ),
    ));

    return testDocumentContext;
  }
}

class TestDocumentContext {
  const TestDocumentContext._({
    required this.focusNode,
    required this.layoutKey,
    required this.editContext,
  });

  final FocusNode focusNode;
  final GlobalKey layoutKey;
  final EditContext editContext;
}

Matcher documentEquivalentTo(Document expectedDocument) => EquivalentDocumentMatcher(expectedDocument);

class EquivalentDocumentMatcher extends Matcher {
  const EquivalentDocumentMatcher(this._expectedDocument);

  final Document _expectedDocument;

  @override
  Description describe(Description description) {
    return description.add("given Document has equivalent content to expected Document");
  }

  @override
  bool matches(covariant Object target, Map<dynamic, dynamic> matchState) {
    return _calculateMismatchReason(target, matchState) == null;
  }

  @override
  Description describeMismatch(
    covariant Object target,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final mismatchReason = _calculateMismatchReason(target, matchState);
    if (mismatchReason != null) {
      mismatchDescription.add(mismatchReason);
    }
    return mismatchDescription;
  }

  String? _calculateMismatchReason(
    Object target,
    Map<dynamic, dynamic> matchState,
  ) {
    late Document actualDocument;
    if (target is Document) {
      actualDocument = target;
    } else {
      // If we weren't given a Document, then we expect to receive a Finder
      // that locates a SuperEditor, which contains a Document.
      if (target is! Finder) {
        return "the given target isn't a Document or a Finder: $target";
      }

      final document = SuperEditorInspector.findDocument(target);
      if (document == null) {
        return "Finder didn't match any SuperEditor widgets: $Finder";
      }
      actualDocument = document;
    }

    final messages = <String>[];
    bool nodeCountMismatch = false;
    bool nodeTypeOrContentMismatch = false;

    if (_expectedDocument.nodes.length != actualDocument.nodes.length) {
      messages
          .add("expected ${_expectedDocument.nodes.length} document nodes but found ${actualDocument.nodes.length}");
      nodeCountMismatch = true;
    } else {
      messages.add("document have the same number of nodes");
    }

    final maxNodeCount = max(_expectedDocument.nodes.length, actualDocument.nodes.length);
    final nodeComparisons = List.generate(maxNodeCount, (index) => ["", "", " "]);
    for (int i = 0; i < maxNodeCount; i += 1) {
      if (i < _expectedDocument.nodes.length && i < actualDocument.nodes.length) {
        nodeComparisons[i][0] = _expectedDocument.nodes[i].runtimeType.toString();
        nodeComparisons[i][1] = actualDocument.nodes[i].runtimeType.toString();

        if (_expectedDocument.nodes[i].runtimeType != actualDocument.nodes[i].runtimeType) {
          nodeComparisons[i][2] = "Wrong Type";
          nodeTypeOrContentMismatch = true;
        } else if (!_expectedDocument.nodes[i].hasEquivalentContent(actualDocument.nodes[i])) {
          nodeComparisons[i][2] = "Different Content";
          nodeTypeOrContentMismatch = true;
        }
      } else if (i < _expectedDocument.nodes.length) {
        nodeComparisons[i][0] = _expectedDocument.nodes[i].runtimeType.toString();
        nodeComparisons[i][1] = "NA";
        nodeComparisons[i][2] = "Missing Node";
      } else if (i < actualDocument.nodes.length) {
        nodeComparisons[i][0] = "NA";
        nodeComparisons[i][1] = actualDocument.nodes[i].runtimeType.toString();
        nodeComparisons[i][2] = "Missing Node";
      }
    }

    if (nodeCountMismatch || nodeTypeOrContentMismatch) {
      String messagesList = messages.join(", ");
      messagesList += "\n";
      messagesList += const TableRenderer().render(nodeComparisons, columns: ["Expected", "Actual", "Difference"]);
      return messagesList;
    }

    return null;
  }
}
