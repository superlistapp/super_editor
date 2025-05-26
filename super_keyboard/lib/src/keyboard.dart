/// Mobile application window geometry as reported by the `super_keyboard` plugin.
///
/// This geometry includes values that are deemed relevant to keyboard behavior, but excludes
/// geometry that's unrelated to keyboards, such as gesture areas on the left/right/top of the
/// screen, and the space taken up by the camera at the top of the screen.
class MobileWindowGeometry {
  const MobileWindowGeometry({
    this.keyboardState,
    this.keyboardHeight,
    this.bottomPadding,
  });

  /// The current state of the software keyboard, e.g., open, opening, closed, closing.
  final KeyboardState? keyboardState;

  /// The current height of the software keyboard.
  ///
  /// This height might reflect a keyboard that's completely open, completely closed,
  /// in the process of opening, or in the process of closing.
  final double? keyboardHeight;

  /// Bottom padding that the OS expects apps to respect when the keyboard is closed.
  ///
  /// This gap might represent, for example, an OS draggable area at the bottom of the screen,
  /// which is used to open the app switcher.
  final double? bottomPadding;

  /// Returns a copy of this [MobileWindowGeometry] with the [newValues] applied
  /// on top, i.e., replaces values in this [MobileWindowGeometry] with values from
  /// the given [newValues].
  MobileWindowGeometry updateWith(MobileWindowGeometry newValues) {
    return copyWith(
      keyboardState: newValues.keyboardState,
      keyboardHeight: newValues.keyboardHeight,
      bottomPadding: newValues.bottomPadding,
    );
  }

  /// Returns a copy of [baseValues] with values from this [MobileWindowGeometry] applied on top, i.e.,
  /// the values in this [MobileWindowGeometry] replace values in [baseValues].
  MobileWindowGeometry applyTo(MobileWindowGeometry baseValues) {
    return baseValues.updateWith(this);
  }

  MobileWindowGeometry copyWith({
    KeyboardState? keyboardState,
    double? keyboardHeight,
    double? bottomPadding,
  }) {
    return MobileWindowGeometry(
      keyboardState: keyboardState ?? this.keyboardState,
      keyboardHeight: keyboardHeight ?? this.keyboardHeight,
      bottomPadding: bottomPadding ?? this.bottomPadding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileWindowGeometry &&
          runtimeType == other.runtimeType &&
          keyboardState == other.keyboardState &&
          keyboardHeight == other.keyboardHeight &&
          bottomPadding == other.bottomPadding;

  @override
  int get hashCode => keyboardState.hashCode ^ keyboardHeight.hashCode ^ bottomPadding.hashCode;
}

enum KeyboardState {
  closed,
  opening,
  open,
  closing;
}
