import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A border that displays with different colors based on common text field states, e.g.,
/// non-focused, focused, error.
class TextFieldBorder extends StatelessWidget {
  const TextFieldBorder({
    super.key,
    required this.focusNode,
    this.hasError,
    required this.borderBuilder,
    this.clipBehavior = Clip.none,
    required this.child,
  });

  final FocusNode focusNode;

  final ValueListenable<bool>? hasError;

  final TextFieldBorderBuilder borderBuilder;

  final Clip clipBehavior;

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
