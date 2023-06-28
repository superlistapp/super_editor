import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

/// Provides access to an IME client, to simulate IME input within a test.
///
/// The given [finder] is used to locate the [ImeInputOwner] that should receive the simulated
/// IME input. If no [finder] is provided, then the tree is searched for an [ImeInputOwner]. In
/// that case, there must only be a single [ImeInputOwner] in the tree.
DeltaTextInputClient imeClientGetter([Finder? finder]) {
  if (finder == null) {
    // Check, specifically, for a SuperTextField because SuperTextField internally contains other
    // widgets that implement ImeInputOwner, so we have to manually disambiguate which one we want.
    final superTextFieldImeOwner = _getSuperTextFieldImeClient();
    if (superTextFieldImeOwner != null) {
      return superTextFieldImeOwner.imeClient;
    }
  }

  // There should only be one ImeInputOwner in the tree, or within the `finder`.
  // Find it and return its IME client.
  final element =
      (finder ?? find.byElementPredicate((element) => element is StatefulElement && element.state is ImeInputOwner))
          .evaluate()
          .single as StatefulElement;
  final owner = element.state as ImeInputOwner;
  return owner.imeClient;
}

ImeInputOwner? _getSuperTextFieldImeClient() {
  final superTextFieldElements = find.byType(SuperTextField).evaluate();
  if (superTextFieldElements.length != 1) {
    return null;
  }

  return (superTextFieldElements.single as StatefulElement).state as ImeInputOwner;
}
