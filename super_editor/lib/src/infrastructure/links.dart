import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart' as url_plugin;

/// Launches URLs, with support for testing overrides.
class UrlLauncher {
  static UrlLauncher get instance {
    _instance ??= UrlLauncher();
    return _instance!;
  }

  static UrlLauncher? _instance;

  @visibleForTesting
  static set instance(UrlLauncher? newInstance) {
    _instance = newInstance ?? UrlLauncher();
  }

  Future<bool> launchUrl(Uri url) {
    return url_plugin.launchUrl(url);
  }
}
