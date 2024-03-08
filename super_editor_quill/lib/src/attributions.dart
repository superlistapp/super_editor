import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

class DeltaAttribution {
  const DeltaAttribution({
    required this.key,
    required this.attribution,
  });

  final String key;
  final Attribution Function(Attribution? attribution, Object? value)
      attribution;
}

final defaultAttributions = <DeltaAttribution>[
  DeltaAttribution(key: 'bold', attribution: (_, __) => boldAttribution),
  DeltaAttribution(key: 'italic', attribution: (_, __) => italicsAttribution),
  DeltaAttribution(
    key: 'underline',
    attribution: (_, __) => underlineAttribution,
  ),
  DeltaAttribution(
    key: 'link',
    attribution: (attribution, url) {
      return attribution ?? LinkAttribution(url: Uri.parse(url as String));
    },
  ),
];
