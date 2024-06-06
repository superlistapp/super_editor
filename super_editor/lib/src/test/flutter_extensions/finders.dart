import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

extension Finders on CommonFinders {
  /// Finds [StatefulElement]s whose [State] is of type [StateType], optionally
  /// scoped to the given [subtreeScope], and returns the element's associated
  /// [StateType] object.
  ///
  /// This method expects to find, at most, one [StateType] object.
  ///
  /// Example - assume a widget MyWidget with a state MyWidgetState:
  ///
  ///     final state = find.state<MyWidgetState>();
  ///     state?.myCustomStateMethod();
  ///
  StateType? state<StateType extends State>([Finder? subtreeScope]) {
    final elementFinder =
        find.byElementPredicate((element) => element is StatefulElement && element.state is StateType);
    final Finder stateFinder =
        subtreeScope != null ? find.descendant(of: subtreeScope, matching: elementFinder) : elementFinder;

    final finderResult = stateFinder.evaluate();
    if (finderResult.length > 1) {
      throw Exception("Expected to find no more than one $StateType, but found ${finderResult.length}");
    }
    if (finderResult.isEmpty) {
      return null;
    }

    final foundElement = stateFinder.evaluate().single as StatefulElement;
    return foundElement.state as StateType;
  }
}

class FindsNothing extends Finder {
  @override
  String get description => "Finder that matches nothing so that a Finder may be returned in defunct situations";
}
