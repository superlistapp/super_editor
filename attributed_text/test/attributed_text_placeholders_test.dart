import 'package:attributed_text/attributed_text.dart';
import 'package:test/test.dart';

void main() {
  group("AttributedAttributed > placeholders >", () {
    group("construction >", () {
      test("reports invalid placeholder positions", () {
        // Index less than zero.
        expect(
          () => AttributedText("Hello, World!", null, {
            -1: const _FakePlaceholder("bad-index"),
          }),
          throwsA(isA<AssertionError>()),
        );

        // Index beyond length.
        expect(
          () => AttributedText("Hello, World!", null, {
            14: const _FakePlaceholder("bad-index"),
          }),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group("length >", () {
      test("only a single placeholder", () {
        expect(
          AttributedText(
            "",
            null,
            {
              0: const _FakePlaceholder("only"),
            },
          ).length,
          1,
        );
      });

      test("only multiple placeholders", () {
        expect(
          AttributedText(
            "",
            null,
            {
              0: const _FakePlaceholder("one"),
              1: const _FakePlaceholder("two"),
              2: const _FakePlaceholder("three"),
            },
          ).length,
          3,
        );
      });

      test("text with a single placeholder", () {
        expect(
          AttributedText(
            "Hello, world! ",
            null,
            {
              14: const _FakePlaceholder("trailing"),
            },
          ).length,
          15,
        );
      });

      test("text with multiple placeholders", () {
        expect(
          AttributedText(
            "Hello, world! ",
            null,
            {
              0: const _FakePlaceholder("leading"),
              6: const _FakePlaceholder("middle"),
              16: const _FakePlaceholder("trailing"),
            },
          ).length,
          17,
        );
      });
    });

    test("reports plain text value", () {
      expect(
        AttributedText("", null, {
          0: const _FakePlaceholder("only"),
        }).toPlainText(replacementCharacter: "�"),
        "�",
      );

      expect(
        AttributedText("", null, {
          0: const _FakePlaceholder("one"),
          1: const _FakePlaceholder("two"),
          2: const _FakePlaceholder("three"),
        }).toPlainText(replacementCharacter: "�"),
        "���",
      );

      expect(
        AttributedText("HelloWorld", null, {
          0: const _FakePlaceholder("one"),
          6: const _FakePlaceholder("two"),
          12: const _FakePlaceholder("three"),
        }).toPlainText(replacementCharacter: "�"),
        "�Hello�World�",
      );
    });

    group("plain text substring >", () {
      test("when placeholders are not in range", () {
        expect(
          AttributedText("Hello, world!", null, {
            0: const _FakePlaceholder("leading"),
            6: const _FakePlaceholder("middle"),
            15: const _FakePlaceholder("trailing"),
          }).substring(1, 6),
          "Hello",
        );
      });

      test("with placeholders in the range", () {
        expect(
          AttributedText("Hello, world!", null, {
            0: const _FakePlaceholder("leading"),
            6: const _FakePlaceholder("middle"),
            15: const _FakePlaceholder("trailing"),
          }).substring(0, 7),
          "Hello",
        );
      });
    });

    group("equality >", () {
      test("only a single placeholder", () {
        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("only"),
          }),
          equals(
            AttributedText("", null, {
              0: const _FakePlaceholder("only"),
            }),
          ),
        );

        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("only"),
          }),
          isNot(
            equals(
              AttributedText("", null),
            ),
          ),
        );

        expect(
          AttributedText("", null),
          isNot(
            equals(
              AttributedText("", null, {
                0: const _FakePlaceholder("only"),
              }),
            ),
          ),
        );
      });

      test("some of multiple placeholders", () {
        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("one"),
            1: const _FakePlaceholder("two"),
            2: const _FakePlaceholder("three"),
          }),
          equals(
            AttributedText("", null, {
              0: const _FakePlaceholder("one"),
              1: const _FakePlaceholder("two"),
              2: const _FakePlaceholder("three"),
            }),
          ),
        );

        expect(
          AttributedText("", null),
          isNot(
            equals(
              AttributedText("", null, {
                0: const _FakePlaceholder("one"),
                1: const _FakePlaceholder("two"),
                2: const _FakePlaceholder("three"),
              }),
            ),
          ),
        );

        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("one"),
            1: const _FakePlaceholder("two"),
            2: const _FakePlaceholder("three"),
          }),
          isNot(
            equals(
              AttributedText("", null),
            ),
          ),
        );
      });

      test("some text and a placeholder", () {
        expect(
          AttributedText("Hello, world!", null, {
            5: const _FakePlaceholder("middle"),
          }),
          equals(
            AttributedText("Hello, world!", null, {
              5: const _FakePlaceholder("middle"),
            }),
          ),
        );

        expect(
          AttributedText("Hello, world!", null),
          isNot(
            equals(
              AttributedText("Hello, world!", null, {
                5: const _FakePlaceholder("middle"),
              }),
            ),
          ),
        );

        expect(
          AttributedText("Hello, world!", null, {
            5: const _FakePlaceholder("middle"),
          }),
          isNot(
            equals(
              AttributedText("Hello, world!", null),
            ),
          ),
        );
      });
    });

    group("full copy >", () {
      test("only a single placeholder", () {
        expect(
          AttributedText(
              "",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
              {
                0: const _FakePlaceholder("only"),
              }).copy(),
          AttributedText(
              "",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.end),
                ],
              ),
              {
                0: const _FakePlaceholder("only"),
              }),
        );
      });

      test("some of multiple placeholders", () {
        expect(
          AttributedText(
              "",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 1, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 2, markerType: SpanMarkerType.end),
                ],
              ),
              {
                0: const _FakePlaceholder("one"),
                1: const _FakePlaceholder("two"),
                2: const _FakePlaceholder("three"),
              }).copy(),
          AttributedText(
              "",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 1, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 2, markerType: SpanMarkerType.end),
                ],
              ),
              {
                0: const _FakePlaceholder("one"),
                1: const _FakePlaceholder("two"),
                2: const _FakePlaceholder("three"),
              }),
        );
      });

      test("some text and a placeholder", () {
        expect(
          AttributedText(
              "Hello, world!",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 5, markerType: SpanMarkerType.end),
                ],
              ),
              {
                5: const _FakePlaceholder("middle"),
              }).copy(),
          AttributedText(
              "Hello, world!",
              AttributedSpans(
                attributions: const [
                  SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
                  SpanMarker(attribution: _bold, offset: 5, markerType: SpanMarkerType.end),
                ],
              ),
              {
                5: const _FakePlaceholder("middle"),
              }),
        );
      });
    });

    group("copy span >", () {
      test("only a single placeholder", () {
        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("only"),
          }).copyText(0, 1),
          AttributedText("", null, {
            0: const _FakePlaceholder("only"),
          }),
        );
      });

      test("some of multiple placeholders", () {
        expect(
          AttributedText("", null, {
            0: const _FakePlaceholder("one"),
            1: const _FakePlaceholder("two"),
            2: const _FakePlaceholder("three"),
          }).copyText(1, 3),
          AttributedText("", null, {
            0: const _FakePlaceholder("two"),
            1: const _FakePlaceholder("three"),
          }),
        );
      });

      test("some text and a leading placeholder", () {
        expect(
          AttributedText("Hello, world!", null, {
            0: const _FakePlaceholder("leading"),
          }).copyText(0, 6),
          AttributedText("Hello", null, {
            0: const _FakePlaceholder("leading"),
          }),
        );
      });

      test("some text and a middle placeholder", () {
        expect(
          AttributedText("Hello, world!", null, {
            5: const _FakePlaceholder("middle"),
          }).copyText(0, 6),
          AttributedText("Hello", null, {
            5: const _FakePlaceholder("middle"),
          }),
        );
      });

      test("some text and a trailing placeholder", () {
        expect(
          AttributedText("Hello, world!", null, {
            13: const _FakePlaceholder("trailing"),
          }).copyText(7, 14),
          AttributedText("world!", null, {
            6: const _FakePlaceholder("trailing"),
          }),
        );
      });
    });

    group("copy and append >", () {
      test("only a single placeholder", () {
        expect(
          AttributedText("Hello").copyAndAppend(
            AttributedText("", null, {
              0: const _FakePlaceholder("only"),
            }),
          ),
          AttributedText("Hello", null, {
            5: const _FakePlaceholder("only"),
          }),
        );
      });

      test("some of multiple placeholders", () {
        expect(
          AttributedText("Hello").copyAndAppend(
            AttributedText("", null, {
              0: const _FakePlaceholder("one"),
              1: const _FakePlaceholder("two"),
              2: const _FakePlaceholder("three"),
            }),
          ),
          AttributedText("Hello", null, {
            5: const _FakePlaceholder("one"),
            6: const _FakePlaceholder("two"),
            7: const _FakePlaceholder("three"),
          }),
        );
      });

      test("some text and a leading placeholder", () {
        expect(
          AttributedText("Hello").copyAndAppend(
            AttributedText(", world!", null, {
              0: const _FakePlaceholder("middle"),
            }),
          ),
          AttributedText("Hello, world!", null, {
            5: const _FakePlaceholder("middle"),
          }),
        );
      });

      test("some text and a middle placeholder", () {
        expect(
          AttributedText("Hello").copyAndAppend(
            AttributedText(", world!", null, {
              2: const _FakePlaceholder("middle"),
            }),
          ),
          AttributedText("Hello, world!", null, {
            7: const _FakePlaceholder("middle"),
          }),
        );
      });

      test("some text and a trailing placeholder", () {
        expect(
          AttributedText("Hello").copyAndAppend(
            AttributedText(", world!", null, {
              8: const _FakePlaceholder("trailing"),
            }),
          ),
          AttributedText("Hello, world!", null, {
            13: const _FakePlaceholder("trailing"),
          }),
        );
      });
    });

    test("insert attributed text >", () {
      final empty = AttributedText("");
      final hello = empty.insert(
        textToInsert: AttributedText("Hello", null, {
          5: const _FakePlaceholder("middle"),
        }),
        startOffset: 0,
      );
      final helloWorld = hello.insert(
        textToInsert: AttributedText(", World!", null, {
          8: const _FakePlaceholder("trailing"),
        }),
        startOffset: 6,
      );

      expect(
        hello,
        AttributedText("Hello", null, {
          5: const _FakePlaceholder("middle"),
        }),
      );

      expect(
        helloWorld,
        AttributedText("Hello, World!", null, {
          5: const _FakePlaceholder("middle"),
          14: const _FakePlaceholder("trailing"),
        }),
      );
    });

    group("insert placeholders >", () {
      test("multiple placeholders", () {
        expect(
          AttributedText("Hello, World!").insertPlaceholders({
            0: const _FakePlaceholder("leading"),
            6: const _FakePlaceholder("middle"),
            14: const _FakePlaceholder("trailing"),
          }),
          AttributedText("Hello, World!", null, {
            0: const _FakePlaceholder("leading"),
            6: const _FakePlaceholder("middle"),
            14: const _FakePlaceholder("trailing"),
          }),
        );
      });

      test("individual placeholder", () {
        expect(
          AttributedText().insertPlaceholder(0, const _FakePlaceholder("only")),
          AttributedText("", null, {
            0: const _FakePlaceholder("only"),
          }),
        );

        expect(
          AttributedText("Hello").insertPlaceholder(5, const _FakePlaceholder("only")),
          AttributedText("Hello", null, {
            5: const _FakePlaceholder("only"),
          }),
        );
      });
    });

    test("remove region >", () {
      expect(
        AttributedText(
          "Hello, World!",
          AttributedSpans(
            attributions: const [
              SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: _bold, offset: 4, markerType: SpanMarkerType.end),
            ],
          ),
          {
            5: const _FakePlaceholder("middle"),
          },
        ).removeRegion(startOffset: 0, endOffset: 5),
        AttributedText(
          ", World!",
          null,
          {
            0: const _FakePlaceholder("middle"),
          },
        ),
      );

      expect(
        AttributedText(
          "Hello, World!",
          AttributedSpans(
            attributions: const [
              SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: _bold, offset: 5, markerType: SpanMarkerType.end),
            ],
          ),
          {
            5: const _FakePlaceholder("middle"),
          },
        ).removeRegion(startOffset: 3, endOffset: 10),
        AttributedText(
          "Helrld!",
          AttributedSpans(
            attributions: const [
              SpanMarker(attribution: _bold, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: _bold, offset: 2, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      );
    });
  });
}

const _bold = NamedAttribution("bold");

class _FakePlaceholder {
  const _FakePlaceholder(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FakePlaceholder && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
