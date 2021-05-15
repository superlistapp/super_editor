import 'dart:html';

final _platform = window.navigator.platform ?? '';
final isMac = _platform.startsWith('Mac');
