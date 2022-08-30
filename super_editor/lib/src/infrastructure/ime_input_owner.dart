import 'package:flutter/services.dart';

/// A widget that internally accepts IME input.
///
/// Tests may wish to simulate IME input, in which case the test needs to obtain a reference to the
/// [DeltaTextInputClient], because Flutter doesn't make it possible to truly simulate platform IME input
/// (https://github.com/flutter/flutter/issues/107130). The [DeltaTextInputClient] might be implemented by
/// any given widget in a subtree, or it might be implemented by a non-widget class, such as a controller.
/// This interface hides those details and ensures that the [DeltaTextInputClient] is available, by contract,
/// from whichever class implements this interface.
abstract class ImeInputOwner {
  DeltaTextInputClient get imeClient;
}
