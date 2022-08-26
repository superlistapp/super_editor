import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';

/// Provides access to an IME client, to simulate IME input within a test.
///
/// The given [finder] is used to locate the [ImeInputOwner] that should receive the simulated
/// IME input. If no [finder] is provided, then the tree is searched for an [ImeInputOwner]. In
/// that case, there must only be a single [ImeInputOwner] in the tree.
DeltaTextInputClient imeClientGetter([Finder? finder]) {
  final element =
      (finder ?? find.byElementPredicate((element) => element is StatefulElement && element.state is ImeInputOwner))
          .evaluate()
          .single as StatefulElement;
  final owner = element.state as ImeInputOwner;
  return owner.imeClient;
}
