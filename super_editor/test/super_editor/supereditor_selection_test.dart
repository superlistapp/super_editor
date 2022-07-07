import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/layout_single_column.dart';
import 'package:super_editor/src/default_editor/text.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor selection", () {
    testWidgetsOnArbitraryDesktop("calculates upstream document selection within a single node", (tester) async {
      await tester //
          .createDocument() //
          .fromMarkdown("This all fits on one line.") //
          .pump();

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;
      final globalLayoutOrigin = (layoutState.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

      // Drag from upper-right to lower-left.
      //
      // By dragging in this exact direction, we're purposefully introducing contrary
      // directions: right-to-left is upstream for a single line, and up-to-down is
      // downstream for multi-node. This test ensures that the single-line direction is
      // honored by the document layout, rather than the more common multi-node calculation.
      final selection = layout.getDocumentSelectionInRegion(
          const Offset(200, 40) + globalLayoutOrigin, const Offset(150, 60) + globalLayoutOrigin);
      expect(selection, isNotNull);

      // Ensure that the document selection is upstream.
      final base = selection!.base.nodePosition as TextNodePosition;
      final extent = selection.extent.nodePosition as TextNodePosition;
      expect(base.offset > extent.offset, isTrue);
    });

    testWidgetsOnArbitraryDesktop("calculates downstream document selection within a single node", (tester) async {
      await tester //
          .createDocument() //
          .fromMarkdown("This all fits on one line.") //
          .pump();

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;
      final globalLayoutOrigin = (layoutState.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

      // Drag from lower-right to upper-left.
      //
      // By dragging in this exact direction, we're purposefully introducing contrary
      // directions: left-to-right is downstream for a single line, and down-to-up is
      // upstream for multi-node. This test ensures that the single-line direction is
      // honored by the document layout, rather than the more common multi-node calculation.
      final selection = layout.getDocumentSelectionInRegion(
          const Offset(150, 60) + globalLayoutOrigin, const Offset(200, 40) + globalLayoutOrigin);
      expect(selection, isNotNull);

      // Ensure that the document selection is downstream.
      final base = selection!.base.nodePosition as TextNodePosition;
      final extent = selection.extent.nodePosition as TextNodePosition;
      expect(base.offset < extent.offset, isTrue);
    });
  });
}
