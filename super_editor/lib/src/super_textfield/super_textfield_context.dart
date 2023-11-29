import 'package:flutter/widgets.dart';
import 'package:super_editor/src/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_field_scroller.dart';
import 'package:super_editor/src/super_textfield/input_method_engine/_ime_text_editing_controller.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Collection of core artifacts used to interact with, and edit, a text field.
class SuperTextFieldContext {
  SuperTextFieldContext({
    required this.textFieldBuildContext,
    required this.focusNode,
    required this.controller,
    required this.getTextLayout,
    required this.scroller,
  });

  /// A [BuildContext] that's bound to the text field.
  ///
  /// This [BuildContext] is provided so that behaviors, like key handlers, can
  /// interact with ancestor widgets, such as ancestor scrollables.
  ///
  /// This context may or may not point to the root [Element] of the text field. That
  /// said, it will point to an [Element] near the root of the text field, and the
  /// associated render object will match the outer bounds of the text field.
  final BuildContext textFieldBuildContext;

  /// The [FocusNode] associated with the text field.
  final FocusNode focusNode;

  /// Controller that owns the text content, selection, composing region and any
  /// other text-editing state for the associated text field.
  final AttributedTextEditingController controller;

  /// The [controller], cast as an [ImeAttributedTextEditingController], or `null`
  /// if [controller] is not an [ImeAttributedTextEditingController].
  ImeAttributedTextEditingController? get imeController =>
      controller is ImeAttributedTextEditingController ? controller as ImeAttributedTextEditingController : null;

  /// Returns a `Function`, which, when invoked, returns a reference to the
  /// text field's [ProseTextLayout], which can be used to query the visual
  /// bounds of text.
  final SuperTextFieldLayoutResolver getTextLayout;

  /// Controller to query and change the scroll offset within the associated
  /// text field.
  final TextFieldScroller scroller;
}

/// Function that returns the text layout for a text field.
typedef SuperTextFieldLayoutResolver = ProseTextLayout Function();
