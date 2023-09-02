import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/links.dart';

/// A [UrlLauncher] that logs each attempt to launch a URL, but doesn't
/// attempt to actually launch the URLs.
class TestUrlLauncher implements UrlLauncher {
  final _urlLaunchLog = <Uri>[];

  List<Uri> get urlLaunchLog => _urlLaunchLog;

  void clearUrlLaunchLog() => _urlLaunchLog.clear();

  @override
  Future<bool> launchUrl(Uri url) async {
    _urlLaunchLog.add(url);
    return true;
  }
}
