import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/table.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

void main() {
  group('Markdown > deserialization > tables >', () {
    group('parses', () {
      test('table with single column', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 |
|---|
| data 1 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
              ],
            ],
          ),
        );
      });

      test('table with two columns', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table with multiple rows', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
| data 3 | data 4 |
| data 5 | data 6 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
              [
                AttributedText('data 3'),
                AttributedText('data 4'),
              ],
              [
                AttributedText('data 5'),
                AttributedText('data 6'),
              ],
            ],
          ),
        );
      });

      test('table with alignment', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 | header 3 |
|:---|:---:|---:|
| data 1 | data 2 | data 3 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
                textAlign: TextAlign.left,
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
                textAlign: TextAlign.center,
              ),
              MarkdownColumn(
                header: AttributedText('header 3'),
                textAlign: TextAlign.right,
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
                AttributedText('data 3'),
              ],
            ],
          ),
        );
      });

      test('table with inline markdown', () {
        expect(
          _parseMarkdownTable(
            '''| **header 1** |
|---|
| [link](https://example.org) |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText(
                    'header 1',
                    AttributedSpans(
                      attributions: [
                        const SpanMarker(
                          attribution: boldAttribution,
                          offset: 0,
                          markerType: SpanMarkerType.start,
                        ),
                        const SpanMarker(
                          attribution: boldAttribution,
                          offset: 7,
                          markerType: SpanMarkerType.end,
                        ),
                      ],
                    )),
              ),
            ],
            rows: [
              [
                AttributedText(
                  'link',
                  AttributedSpans(
                    attributions: [
                      const SpanMarker(
                          attribution: LinkAttribution('https://example.org'),
                          offset: 0,
                          markerType: SpanMarkerType.start),
                      const SpanMarker(
                          attribution: LinkAttribution('https://example.org'),
                          offset: 3,
                          markerType: SpanMarkerType.end),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      });

      test('table without body', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [],
          ),
        );
      });

      test('table with text containing pipe', () {
        expect(
          _parseMarkdownTable(
            '''| header\\|1 |
|---|
| data\\|1 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header|1'),
              ),
            ],
            rows: [
              [
                AttributedText('data|1'),
              ],
            ],
          ),
        );
      });

      test('table with inline markdown containing pipe', () {
        expect(
          _parseMarkdownTable(
            '''| header **\\|1** |
|---|
| data 1 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText(
                  'header |1',
                  AttributedSpans(
                    attributions: [
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 7,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 8,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
              ],
            ],
          ),
        );
      });

      test('table with delimiter with more than three hyphens', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|----------|
| data 1 | data 2 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table without leading pipe', () {
        expect(
          _parseMarkdownTable(
            '''header 1 | header 2 |
---|---|
 data 1 | data 2 |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table without trailing pipe', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 
|---|---
| data 1 | data 2 ''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table without leading and trailing pipe', () {
        expect(
          _parseMarkdownTable(
            '''header 1 | header 2 
---|---
data 1 | data 2 ''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table with row with missing column', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText(''),
              ],
            ],
          ),
        );
      });

      test('table with row with extra column', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 | extra data |''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table with tabs between columns', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 	| header 2 	| header 3 	|
|---	|---	|---	|
| data 1 	| data 2 	| data 3 	|''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
              MarkdownColumn(
                header: AttributedText('header 3'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
                AttributedText('data 3'),
              ],
            ],
          ),
        );
      });

      test('table broken by block level element', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
> blockquote''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
            ],
          ),
        );
      });

      test('table broken by empty line', () {
        expect(
          _parseMarkdownTable(
            '''| header 1 | header 2 |
|---|---|
| data 1 | data 2 |
data 3

paragraph''',
          ),
          MarkdownTable(
            headers: [
              MarkdownColumn(
                header: AttributedText('header 1'),
              ),
              MarkdownColumn(
                header: AttributedText('header 2'),
              ),
            ],
            rows: [
              [
                AttributedText('data 1'),
                AttributedText('data 2'),
              ],
              [
                AttributedText('data 3'),
                AttributedText(''),
              ],
            ],
          ),
        );
      });
    });

    test('rejects delimiter with mismatch cell count', () {
      expect(
        () => _parseMarkdownTable(
          '''| header 1 | header 2 |
|---|
| data 1 | data 2 |''',
        ),
        throwsException,
      );
    });
  });
}

/// Parses the given [markdown] string and attempts to extract a table
/// from the first element.
///
/// All subsequent elements are ignored.
MarkdownTable _parseMarkdownTable(String markdown) {
  final nodes = parseMarkdownNodes(markdown);
  final table = convertTable(nodes[0] as Element);

  return MarkdownTable(
    headers: table.headers,
    rows: table.rows,
  );
}
