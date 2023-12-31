import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    ..pick(DirectoryPicker.parse("images"))
    ..pick(DirectoryPicker.parse("_styles"))
    ..plugin(const MarkdownPlugin())
    ..plugin(const JinjaPlugin())
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const SassPlugin())
    ..plugin(const PubPackagePlugin({
      "super_editor",
      "super_text_layout",
      "attributed_text",
    }));

  // Generate the static website.
  await staticShock.generateSite();
}
