// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

final _platform = window.navigator.platform ?? '';
final isMac = _platform.startsWith('Mac');
