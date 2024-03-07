import 'dart:convert';

import 'package:js/js.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

class JsGlue {
  const JsGlue();

  void setInitialQuillContentsChangedListener(
    void Function(Delta contents) listener,
  ) {
    void jsListener(String contents) {
      listener(Delta.fromJson(json.decode(contents)));
    }

    _initialQuillContentsChangedListener = allowInterop(jsListener);
  }

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

  void updateQuillContents(Delta delta) {
    _updateQuillContents(jsonEncode(delta.toJson()));
  }

  void initializeQuillEditor() {
    _initializeQuillEditor();
  }
}

@JS('initializeQuillEditor')
external void _initializeQuillEditor();

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
