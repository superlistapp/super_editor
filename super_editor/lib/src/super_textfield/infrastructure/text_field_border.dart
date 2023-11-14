import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A border that displays with different colors based on common text field states, e.g.,
/// non-focused, focused, error.
///
/// The border visuals are chosen by a provided [borderBuilder]. The border state is refreshed,
/// and the [borderBuilder] is re-run, every time focus changes, or the error state changes.
class TextFieldBorder extends StatelessWidget {
  const TextFieldBorder({
    super.key,
    required this.focusNode,
    this.hasError,
    required this.borderBuilder,
    this.clipBehavior = Clip.none,
    required this.child,
  });

  /// The [FocusNode] associated with the [child] text field.
  final FocusNode focusNode;

  /// Whether the [child] text field is currently in an error state.
  final ValueListenable<bool>? hasError;

  /// Creates a visual border decoration based on a given [TextFieldBorderState].
  final TextFieldBorderBuilder borderBuilder;

  /// Clipping strategy, which defaults to [Clip.none], and can be used to clip [child]
  /// text field content when rounded corners are used for the border.
  final Clip clipBehavior;

  /// The widget subtree that displays a text field, to which this border applies.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hasError ?? ValueNotifier<bool>(false),
      builder: (context, hasError, child) {
        return ListenableBuilder(
          listenable: focusNode,
          builder: (context, child) {
            return Container(
              decoration: borderBuilder(_borderState),
              clipBehavior: clipBehavior,
              child: child,
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }

  TextFieldBorderState get _borderState => TextFieldBorderState(
        hasFocus: focusNode.hasFocus,
        hasPrimaryFocus: focusNode.hasPrimaryFocus,
        hasError: hasError?.value ?? false,
      );
}

/// Properties that might impact the visual appearance of a text field border.
///
/// [TextFieldBorder] provides a [TextFieldBorderState] to a [TextFieldBorderBuilder]
/// to create the desired visual border for a text field.
class TextFieldBorderState {
  const TextFieldBorderState({
    required this.hasFocus,
    required this.hasPrimaryFocus,
    required this.hasError,
  });

  final bool hasFocus;
  final bool hasPrimaryFocus;
  final bool hasError;
}

typedef TextFieldBorderBuilder = BoxDecoration Function(TextFieldBorderState borderState);
