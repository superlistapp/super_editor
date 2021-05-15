import 'package:flutter/services.dart';

import 'platform_detector.dart';

extension PrimaryShortcutKey on RawKeyEvent {
  bool get isPrimaryShortcutKeyPressed =>
      (Platform.instance.isMac && isMetaPressed) || (!Platform.instance.isMac && isControlPressed);
}

/// On web, Flutter reports control character labels as
/// the [RawKeyEvent.character], which we don't want.
/// Until Flutter fixes the problem, this blacklist
/// identifies the keys that we should ignore for the
/// purpose of text/character entry.
const webBugBlacklistCharacters = {
  'Dead',
  'Shift',
  'Alt',
  'Escape',
  'CapsLock',
  'PageUp',
  'PageDown',
  'Home',
  'End',
  'Control',
  'Meta',
  'Enter',
  'Backspace',
  'Delete',
  'F1',
  'F2',
  'F3',
  'F4',
  'F5',
  'F6',
  'F7',
  'F8',
  'F9',
  'F10',
  'F11',
  'F12',
  'Num Lock',
  'Scroll Lock',
  'Insert',
  'Paste',
  'Print Screen',
  'Power',
};
