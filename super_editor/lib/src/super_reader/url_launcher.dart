import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/super_reader/document_tap_handling.dart';

/// A [DocumentTapOnTextDelegate] that reacts to a tap on [LinkAttribution]s
/// by launching the URL in the link.
class DocumentUrlLauncher extends DocumentTapOnTextDelegate {
  const DocumentUrlLauncher(this._launchDelegate);

  /// Delegate that launches a given URL.
  ///
  /// There is no implementation for a [UrlLauncherDelegate] in `super_editor`
  /// because it would require a package dependency that isn't otherwise critical.
  /// Developers should include their URL launching implementation of choice, and
  /// then implement a [UrlLauncherDelegate] as needed.
  final UrlLauncherDelegate _launchDelegate;

  @override
  bool onTextTap({
    required Document document,
    required DocumentNode node,
    required DocumentComponent<StatefulWidget> component,
    required Offset componentTapOffset,
    required TextPosition tappedTextPosition,
    required Set<Attribution> tappedAttributions,
  }) {
    final link =
        tappedAttributions.firstWhereOrNull((attribution) => attribution is LinkAttribution) as LinkAttribution?;
    if (link == null) {
      return false;
    }

    final didLaunch = _launchDelegate.launchUri(link.url);

    // If we launched the URL, prevent the caret from moving, or selection from collapsing.
    // Otherwise, let the normal selection behavior take place.
    return didLaunch;
  }
}

/// Delegate that launches URLs.
abstract class UrlLauncherDelegate {
  /// Launches a URL based on a URL `String`.
  ///
  /// Returns `true` if the URL was launched, or `false` if something prevented the launch.
  bool launchUrlString(String url);

  /// Launches a URL based on a [Uri].
  ///
  /// Returns `true` if the URL was launched, or `false` if something prevented the launch.
  bool launchUri(Uri url);
}
