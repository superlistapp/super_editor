import 'dart:convert';

import 'package:js/js.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

/// A convenience class that handles the ping-pong between the Dart side and the
/// Javascript realm defined in web/index.html for the example app.
class JsGlue {
  const JsGlue();

  /// Initializes the Quill editor on the Javascript side.
  ///
  /// The [domId] is the id of the [HtmlElementView] initialized on the Flutter
  /// side.
  void initializeQuillEditor(String domId) {
    _initializeQuillEditor(domId);
  }

  /// Updates the Quill editor contents on the Javascript side by applying the
  /// given [change] delta.
  void updateQuillContents(Delta change) {
    _updateQuillContents(jsonEncode(change.toJson()));
  }

  /// Sets the listener to be called when the Quill editor is first initialized
  /// and the initial contents of it are sent for the first time.
  void setInitialQuillContentsChangedListener(
    void Function(Delta contents) listener,
  ) {
    void jsListener(String contents) {
      listener(Delta.fromJson(json.decode(contents)));
    }

    _initialQuillContentsChangedListener = allowInterop(jsListener);
  }

  /// Sets the listener to be called when the contents of the Quill editor are
  /// modified by a user action.
  ///
  /// The [document] is the full editor contents and the [change] is the most
  /// minimal representation of what changed in the document.
  void setQuillTextChangedListener(
    void Function(Delta document, Delta change) listener,
  ) {
    void jsListener(String document, String change) {
      listener(
        Delta.fromJson(json.decode(document)),
        Delta.fromJson(json.decode(change)),
      );
    }

    _quillTextChangedListener = allowInterop(jsListener);
  }
}

@JS('initializeQuillEditor')
external void _initializeQuillEditor(String domId);

@JS('updateQuillContents')
external void _updateQuillContents(String contents);

@JS('sendQuillContents')
external set _initialQuillContentsChangedListener(
  void Function(String contents) fn,
);

@JS('onQuillTextChanged')
external set _quillTextChangedListener(
  void Function(String document, String change) fn,
);
