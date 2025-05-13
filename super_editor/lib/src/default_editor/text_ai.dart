import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/text.dart';

// /// Editor request handlers for AI text-insertion behaviors.
// final aiTextInsertionHandlers = [
//   (editor, request) => request is InsertFadingStyledTextAtCaretRequest //
//       ? InsertStyledTextAtCaretCommand(
//           request.text.copy()
//             ..addAttribution(
//               CreatedAtAttribution(start: DateTime.now()),
//               SpanRange(0, request.text.length - 1),
//             ),
//         )
//       : null,
//   (editor, request) => request is InsertFadingInlinePlaceholderAtCaretRequest //
//       ? InsertStyledTextAtCaretCommand(
//           AttributedText("", null, {
//             0: request.placeholder,
//           })
//             ..addAttribution(
//               CreatedAtAttribution(start: DateTime.now()),
//               const SpanRange(0, 0),
//             ),
//         )
//       : null,
//   (editor, request) => request is InsertFadingTextRequest
//       ? InsertTextCommand(
//           documentPosition: request.documentPosition,
//           textToInsert: request.textToInsert,
//           attributions: {
//             ...request.attributions,
//             CreatedAtAttribution(start: DateTime.now()),
//           },
//         )
//       : null,
//   (editor, request) => request is InsertFadingAttributedTextRequest
//       ? InsertAttributedTextCommand(
//           documentPosition: request.documentPosition,
//           textToInsert: request.textToInsert.copy()
//             ..addAttribution(
//               CreatedAtAttribution(start: DateTime.now()),
//               SpanRange(0, request.textToInsert.length - 1),
//             ),
//         )
//       : null,
// ];
//
// /// The same as [InsertStyledTextAtCaretRequest], except the inserted text
// /// is attributed for a fade-in effect.
// class InsertFadingStyledTextAtCaretRequest implements EditRequest {
//   const InsertFadingStyledTextAtCaretRequest(this.text);
//
//   final AttributedText text;
// }
//
// /// The same as [InsertInlinePlaceholderAtCaretRequest], except the inserted placeholder
// /// is attributed for a fade-in effect.
// class InsertFadingInlinePlaceholderAtCaretRequest implements EditRequest {
//   const InsertFadingInlinePlaceholderAtCaretRequest(this.placeholder);
//
//   final Object placeholder;
// }
//
// /// The same as [InsertTextRequest], except the inserted text is attributed for a
// /// fade-in effect.
// class InsertFadingTextRequest implements EditRequest {
//   InsertFadingTextRequest({
//     required this.documentPosition,
//     required this.textToInsert,
//     required this.attributions,
//   }) : assert(documentPosition.nodePosition is TextPosition);
//
//   final DocumentPosition documentPosition;
//   final String textToInsert;
//   final Set<Attribution> attributions;
// }
//
// /// The same as [InsertAttributedTextRequest], except the inserted text is attributed
// /// for a fade-in effect.
// class InsertFadingAttributedTextRequest implements EditRequest {
//   const InsertFadingAttributedTextRequest(this.documentPosition, this.textToInsert);
//
//   final DocumentPosition documentPosition;
//   final AttributedText textToInsert;
// }

/// An [Attribution] that logs the timestamp when a piece of content was created,
/// such as typing text, or inserting an image.
class CreatedAtAttribution implements Attribution {
  const CreatedAtAttribution({
    required this.start,
  });

  final DateTime start;

  @override
  String get id => 'created-at';

  @override
  bool canMergeWith(Attribution other) {
    if (other is! CreatedAtAttribution) {
      return false;
    }

    return start == other.start;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatedAtAttribution && runtimeType == other.runtimeType && start == other.start;

  @override
  int get hashCode => start.hashCode;
}
