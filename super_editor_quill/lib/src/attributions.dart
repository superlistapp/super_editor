import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

class DeltaBlockAttribution {
  const DeltaBlockAttribution({
    required this.key,
    required this.attribution,
  });

  final String key;
  final Attribution Function(Attribution? attribution, Object? value)
      attribution;
}

class DeltaTextAttribution {
  const DeltaTextAttribution({
    required this.key,
    required this.attribution,
  });

  final String key;
  final Attribution Function(Attribution? attribution, Object? value)
      attribution;
}

final defaultBlockAttributions = <DeltaBlockAttribution>[
  DeltaBlockAttribution(
    key: 'header',
    attribution: (_, value) {
      switch (value) {
        case '1':
        case 1:
          return header1Attribution;
        case '2':
        case 2:
          return header2Attribution;
        case '3':
        case 3:
          return header3Attribution;
        case '4':
        case 4:
          return header4Attribution;
        case '5':
        case 5:
          return header5Attribution;
        case '6':
        case 6:
          return header6Attribution;
        case null:
        case false:
          return paragraphAttribution;
      }

      throw UnimplementedError();
    },
  ),
];

final defaultTextAttributions = <DeltaTextAttribution>[
  DeltaTextAttribution(key: 'bold', attribution: (_, __) => boldAttribution),
  DeltaTextAttribution(
      key: 'italic', attribution: (_, __) => italicsAttribution),
  DeltaTextAttribution(
    key: 'underline',
    attribution: (_, __) => underlineAttribution,
  ),
  DeltaTextAttribution(
    key: 'link',
    attribution: (attribution, url) {
      return attribution ?? LinkAttribution(url: Uri.parse(url as String));
    },
  ),
];
