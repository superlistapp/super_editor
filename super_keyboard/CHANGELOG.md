## [0.1.1] - Mar 27, 2025
 * FIX: Android - Only listen for keyboard changes between `onResume` and `onPause`.
 * FIX: Android - Report closed keyboard upon `onResume` in case it closed after switching the app.
 * ADJUSTMENT: Flutter + Platforms - Make logging controllable.

## [0.1.0] - Dec 22, 2024
Initial release:
 * iOS: Reports keyboard closed, opening, open, and closing. No keyboard height.
 * Android: Reports keyboard closed, opening, open, and closing, as well as keyboard height.
