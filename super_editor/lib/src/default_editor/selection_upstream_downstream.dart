import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';

/// [NodePosition] that either sits at the upstream edge, or the downstream edge of
/// the given content, like sitting before or after an image.
class UpstreamDownstreamNodePosition implements NodePosition {
  const UpstreamDownstreamNodePosition.upstream() : affinity = TextAffinity.upstream;
  const UpstreamDownstreamNodePosition.downstream() : affinity = TextAffinity.downstream;

  const UpstreamDownstreamNodePosition(this.affinity);

  final TextAffinity affinity;

  @override
  String toString() => "[UpstreamDownstreamNodePosition] - $affinity";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamDownstreamNodePosition && runtimeType == other.runtimeType && affinity == other.affinity;

  @override
  int get hashCode => affinity.hashCode;
}

/// A [NodeSelection] for a [DocumentNode] that only supports an upstream and downstream
/// position, like a caret sitting before or after an image.
class UpstreamDownstreamNodeSelection implements NodeSelection {
  const UpstreamDownstreamNodeSelection.all()
      : base = const UpstreamDownstreamNodePosition.upstream(),
        extent = const UpstreamDownstreamNodePosition.downstream();

  const UpstreamDownstreamNodeSelection.collapsedUpstream()
      : base = const UpstreamDownstreamNodePosition.upstream(),
        extent = const UpstreamDownstreamNodePosition.upstream();

  const UpstreamDownstreamNodeSelection.collapsedDownstream()
      : base = const UpstreamDownstreamNodePosition.downstream(),
        extent = const UpstreamDownstreamNodePosition.downstream();

  UpstreamDownstreamNodeSelection.collapsed(UpstreamDownstreamNodePosition position)
      : base = position,
        extent = position;

  UpstreamDownstreamNodeSelection({
    required this.base,
    required this.extent,
  });

  final UpstreamDownstreamNodePosition base;
  final UpstreamDownstreamNodePosition extent;

  bool get isCollapsed => base == extent;

  @override
  String toString() => "[UpstreamDownstreamNodeSelection] - base: $base, extent: $extent";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamDownstreamNodeSelection &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          extent == other.extent;

  @override
  int get hashCode => base.hashCode ^ extent.hashCode;
}
