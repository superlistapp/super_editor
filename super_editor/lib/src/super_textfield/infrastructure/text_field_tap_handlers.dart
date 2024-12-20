import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/super_editor.dart';

/// A [SuperTextFieldTapHandler] that opens links when the user taps text with
/// a [LinkAttribution].
class SuperTextFieldLaunchLinkTapHandler extends SuperTextFieldTapHandler {
  @override
  MouseCursor? mouseCursorForContentHover(SuperTextFieldGestureDetails details) {
    final linkAttribution = _getLinkAttribution(details);
    if (linkAttribution == null) {
      return null;
    }

    return SystemMouseCursors.click;
  }

  @override
  TapHandlingInstruction onTapUp(SuperTextFieldGestureDetails details) {
    final linkAttribution = _getLinkAttribution(details);
    if (linkAttribution == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final uri = Uri.tryParse(linkAttribution.url);
    if (uri == null) {
      // The link is not a valid URI. We can't open it.
      return TapHandlingInstruction.continueHandling;
    }

    UrlLauncher.instance.launchUrl(uri);

    return TapHandlingInstruction.halt;
  }

  /// Returns the [LinkAttribution] at the given [details.textOffset], if any.
  LinkAttribution? _getLinkAttribution(SuperTextFieldGestureDetails details) {
    final textPosition = details.textLayout.getPositionNearestToOffset(details.textOffset);

    final attributions = details.textController.text //
        .getAllAttributionsAt(textPosition.offset)
        .whereType<LinkAttribution>();

    if (attributions.isEmpty) {
      return null;
    }

    return attributions.first;
  }
}
