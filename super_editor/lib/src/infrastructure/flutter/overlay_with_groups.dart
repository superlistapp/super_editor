import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

class OverlayWithGroups {
  static OverlayWithGroups get instance => _instance;
  static final _instance = OverlayWithGroups._();

  OverlayWithGroups._();

  final _entries = PriorityQueue<GroupedOverlayEntry>((a, b) => a.displayPriority.compareTo(b.displayPriority));

  /// Inserts the given [entry] into the app [Overlay] at a z-index determined
  /// by its [entry.displayPriority] as compared to other [GroupedOverlayEntry]s
  /// in the app [Overlay].
  ///
  /// Display priority only applies to [GroupedOverlayEntry]s. The z-index of
  /// any [GroupedOverlayEntry] as compared to traditional [OverlayEntry]s is
  /// undefined.
  void insert(BuildContext context, GroupedOverlayEntry entry) {
    if (_entries.contains(entry)) {
      return;
    }

    _entries.add(entry);
    entry._onInsertion(this);

    Overlay.of(context).rearrange(_entries.toList());
  }

  /// Called by a [GroupedOverlayEntry] when it removes itself from the app
  /// [Overlay], so that [GroupedOverlay] can update its internal accounting
  /// of added entries.
  void _onRemoved(GroupedOverlayEntry entry) {
    _entries.remove(entry);
  }
}

class GroupedOverlayEntry extends OverlayEntry {
  GroupedOverlayEntry({
    required this.displayPriority,
    required super.builder,
    super.opaque = false,
    super.maintainState = false,
  });

  /// Relative display priority which determines the z-index of this [GroupedOverlayEntry]
  /// relative to other [GroupedOverlayEntry]s in the app [Overlay].
  final OverlayGroupPriority displayPriority;

  OverlayWithGroups? _overlay;

  void _onInsertion(OverlayWithGroups overlay) => _overlay = overlay;

  @override
  void remove() {
    super.remove();

    if (_overlay != null) {
      _overlay!._onRemoved(this);
      _overlay = null;
    }
  }
}

class OverlayGroupPriority implements Comparable<OverlayGroupPriority> {
  /// Standard group priority for editing controls, e.g., drag handles, toolbars,
  /// magnifiers.
  static const editingControls = OverlayGroupPriority(10000);

  /// Standard group priority for window chrome, e.g., a toolbar mounted above the
  /// software keyboard.
  static const windowChrome = OverlayGroupPriority(1000000);

  const OverlayGroupPriority(this.priority);

  /// Relative priority for display z-index - higher priority means higher
  /// z-index, e.g., a priority of `1000` will appear in front of a priority
  /// of `10`.
  final int priority;

  @override
  int compareTo(OverlayGroupPriority other) => priority.compareTo(other.priority);
}
