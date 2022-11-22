/// A distance from the leading and trailing boundaries of an
/// axis-aligned area.
class AxisOffset {
  /// No offset from the leading/trailing edges.
  static const zero = AxisOffset.symmetric(0);

  /// Equal leading/trailing edge spacing equal to `amount`.
  const AxisOffset.symmetric(num amount)
      : leading = amount,
        trailing = amount;

  const AxisOffset({
    required this.leading,
    required this.trailing,
  });

  /// Distance from the leading edge of an axis-oriented area.
  final num leading;

  /// Distance from the trailing edge of an axis-oriented area.
  final num trailing;

  @override
  String toString() => '[AxisOffset] - leading: $leading, trailing: $trailing';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AxisOffset && runtimeType == other.runtimeType && leading == other.leading && trailing == other.trailing;

  @override
  int get hashCode => leading.hashCode ^ trailing.hashCode;
}
