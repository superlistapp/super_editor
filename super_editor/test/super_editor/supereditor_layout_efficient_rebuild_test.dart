import 'package:flutter_test/flutter_test.dart';

import '../test_tools.dart';

void main() {
  group("Super Editor layout rebuilds efficiently", () {
    testWidgetsOnAllPlatforms("when the caret moves within a paragraph", (tester) async {
      // TODO:
    });

    testWidgetsOnAllPlatforms("when the caret moves to a different paragraph", (tester) async {
      // TODO:
    });

    testWidgetsOnAllPlatforms("when the caret moves within a horizontal rule", (tester) async {
      // TODO:
    });

    testWidgetsOnAllPlatforms("when the user types into a paragraph", (tester) async {
      // TODO:
    });

    testWidgetsOnAllPlatforms("when the user deletes text across two paragraphs", (tester) async {
      // TODO:
    });

    testWidgetsOnAllPlatforms("when the user drags a selection across multiple paragraphs", (tester) async {
      // TODO:
    });
  });
}

Future<void> _pumpDocument(WidgetTester tester) {
  // TODO:
}
