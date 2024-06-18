import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/super_editor.dart';

abstract interface class InlineDeltaFormat {
  Attribution? from(Operation operation);
}

/// An [InlineDeltaFormat] that filters out any operation that doesn't have
/// an attribute with the given [name].
abstract class FilterByNameInlineDeltaFormat implements InlineDeltaFormat {
  const FilterByNameInlineDeltaFormat(this.name);

  final String name;

  @override
  Attribution? from(Operation operation) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return createAttribution(operation.attributes![name]);
  }

  @protected
  Attribution? createAttribution(String value);
}

class NamedInlineDeltaFormat implements InlineDeltaFormat {
  const NamedInlineDeltaFormat(this.name, this.attribution);

  final String name;
  final Attribution attribution;

  @override
  Attribution? from(Operation operation) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return attribution;
  }
}

class ColorDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _color = "color";

  const ColorDeltaFormat() : super(_color);

  @override
  Attribution? createAttribution(String value) {
    if (!value.startsWith("#")) {
      throw Exception("Unknown color value: '$value' - expected it to start with '#'");
    }
    if (value.length != 7 && value.length != 9) {
      throw Exception("Unknown color value: '$value' - expected either #rrggbb or #aarrggbb");
    }

    late final int colorValue;
    if (value.length == 7) {
      // Value is "#rrggbb" - we need to add full alpha to avoid leading zeros.
      colorValue = int.parse(value.substring(1), radix: 16) + 0xFF000000;
    } else {
      // Value is #aarrggbb.
      colorValue = int.parse(value.substring(1), radix: 16);
    }
    final color = Color(colorValue);

    return ColorAttribution(color);
  }
}

class BackgroundColorDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _background = "background";

  const BackgroundColorDeltaFormat() : super(_background);

  @override
  Attribution? createAttribution(String value) {
    if (!value.startsWith("#")) {
      throw Exception("Unknown color value: '$value' - expected it to start with '#'");
    }
    if (value.length != 7 && value.length != 9) {
      throw Exception("Unknown color value: '$value' (length ${value.length}) - expected either #rrggbb or #aarrggbb");
    }

    late final int colorValue;
    if (value.length == 7) {
      // Value is "#rrggbb" - we need to add full alpha to avoid leading zeros.
      colorValue = int.parse(value.substring(1), radix: 16) + 0xFF000000;
    } else {
      // Value is #aarrggbb.
      colorValue = int.parse(value.substring(1), radix: 16);
    }
    final color = Color(colorValue);

    return BackgroundColorAttribution(color);
  }
}

class SizeDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _size = "size";

  const SizeDeltaFormat() : super(_size);

  @override
  Attribution? createAttribution(Object value) {
    if (value is num) {
      final size = value.toDouble();
      return FontSizeAttribution(size);
    }

    if (value is String) {
      // TODO: handle "huge", "large", "normal", "small"
    }

    return null;
  }
}

class LinkDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _link = "link";

  const LinkDeltaFormat() : super(_link);

  @override
  Attribution? createAttribution(String value) {
    return LinkAttribution(value);
  }
}
