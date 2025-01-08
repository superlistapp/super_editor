import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/sliver_hybrid_stack.dart';

class SuperEditorDebugVisuals extends InheritedWidget {
  static SuperEditorDebugVisualsConfig of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuperEditorDebugVisuals>()!.config;
  }

  static SuperEditorDebugVisualsConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuperEditorDebugVisuals>()?.config;
  }

  const SuperEditorDebugVisuals({
    this.config = const SuperEditorDebugVisualsConfig(),
    required Widget child,
  }) : super(child: child);

  final SuperEditorDebugVisualsConfig config;

  @override
  bool updateShouldNotify(SuperEditorDebugVisuals oldWidget) {
    return config != oldWidget.config;
  }
}

class SuperEditorDebugVisualsConfig {
  const SuperEditorDebugVisualsConfig({
    this.showFocus = false,
    this.showImeConnection = false,
  });

  final bool showFocus;
  final bool showImeConnection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorDebugVisualsConfig &&
          runtimeType == other.runtimeType &&
          showFocus == other.showFocus &&
          showImeConnection == other.showImeConnection;

  @override
  int get hashCode => showFocus.hashCode ^ showImeConnection.hashCode;
}

class SuperEditorFocusDebugVisuals extends StatelessWidget {
  const SuperEditorFocusDebugVisuals({
    Key? key,
    required this.focusNode,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = SuperEditorDebugVisuals.maybeOf(context);
    if (config == null || !config.showFocus) {
      return child;
    }

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, value) {
        final color = focusNode.hasPrimaryFocus
            ? Colors.lightGreenAccent
            : focusNode.hasFocus
                ? Colors.red
                : Colors.grey;

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          position: DecorationPosition.foreground,
          child: child,
        );
      },
    );
  }
}

class SuperEditorImeDebugVisuals extends StatelessWidget {
  const SuperEditorImeDebugVisuals({
    Key? key,
    required this.imeConnection,
    required this.child,
  }) : super(key: key);

  final ValueListenable<TextInputConnection?> imeConnection;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = SuperEditorDebugVisuals.maybeOf(context);
    if (config == null || !config.showImeConnection) {
      return child;
    }

    return AnimatedBuilder(
      animation: imeConnection,
      builder: (context, value) {
        final color = imeConnection.value == null
            ? Colors.grey
            : imeConnection.value!.attached
                ? Colors.greenAccent
                : Colors.red;

        final message = imeConnection.value == null
            ? "NO IME CONNECTION"
            : imeConnection.value!.attached
                ? "ATTACHED TO IME"
                : "DETACHED FROM IME";

        return SliverHybridStack(
          children: [
            // Super Editor
            child,
            // Debug Info
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
