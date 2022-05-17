import 'package:flutter/foundation.dart';

/// [Listenable] that allows clients to [sendSignal()] to notify observers
/// of a change.
///
/// [SignalListenable] is the same as a [ChangeNotifier] that allows clients
/// to directly notify listeners, which [ChangeNotifier] prevents.
class SignalListenable extends ChangeNotifier {
  void sendSignal() => notifyListeners();
}
