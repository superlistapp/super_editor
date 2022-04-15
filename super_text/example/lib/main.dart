import 'package:example/typing_robot.dart';
import 'package:flutter/material.dart';
import 'package:super_text/super_text.dart';
import 'package:super_text/super_text_logging.dart';

import 'rainbow_builder.dart';
import 'user_label_layer.dart';

void main() {
  initLoggers(
    Level.WARNING,
    {
      buildsLog,
      robotLog,
    },
  );

  runApp(const SuperTextExampleApp());
}

class SuperTextExampleApp extends StatelessWidget {
  const SuperTextExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Super Text Example',
      home: SuperTextExampleScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SuperTextExampleScreen extends StatefulWidget {
  const SuperTextExampleScreen({Key? key}) : super(key: key);

  @override
  State<SuperTextExampleScreen> createState() => _SuperTextExampleScreenState();
}

class _SuperTextExampleScreenState extends State<SuperTextExampleScreen> with TickerProviderStateMixin {
  static const _text = TextSpan(
    text: _textMessage,
    style: _textStyle,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SuperTextWithSelection examples
                _buildHeader("SuperTextWithSelection Widget"),
                _buildDescription(
                    "SuperTextWithSelection is a product-level widget that renders text with traditional user selections. If you want to build a custom text decoration experience, see SuperText."),
                _buildSuperDuperText(),
                // _buildSuperTextWithSelectionRobot(),
                // _buildSuperTextWithSelectionStaticSingle(),
                // _buildSuperTextWithSelectionStaticMulti(),
                // // // SuperText examples
                _buildHeader("SuperText Widget"),
                _buildDescription(
                    "SuperText is a platform, upon which you can build various text experiences. A SuperText widget allows you to build an arbitrary UI beneath the text, and above the text."),
                // _buildSingleCaret(),
                // _buildSingleSelectionHighlight(),
                // _buildSingleSelectionHighlightRainbow(),
                // _buildMultiUserSelections(),
                // _buildEmptySelection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF444444),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescription(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF444444),
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSuperDuperText() {
    print("Building super duper text example");
    return SuperText(
      richText: _text,
      // layerBeneathBuilder: SuperDuperTextLayoutLayer(
      //   builder: (context, textLayout) {
      //     print("Building SuperDuperTextLayoutLayer beneath");
      //     print(" - context: $context");
      //     print(" - textLayout: $textLayout");
      //     return Stack(
      //       children: [
      //         TextLayoutSelectionHighlight(
      //           textLayout: textLayout,
      //           style: _primaryHighlightStyle,
      //           selection: const TextSelection(baseOffset: 11, extentOffset: 21),
      //         ),
      //       ],
      //     );
      //   },
      // ),
      layerAboveBuilder: SuperDuperTextLayoutLayer(
        builder: (context, textLayout) {
          print("Building SuperDuperTextLayoutLayer above");
          print(" - context: $context");
          print(" - textLayout: $textLayout");
          return Stack(
            children: [
              TextLayoutCaret(
                textLayout: textLayout,
                style: _primaryCaretStyle,
                position: const TextPosition(offset: 21),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuperTextWithSelectionRobot() {
    return _buildExampleContainer(
      child: const _TypingRobotExample(),
    );
  }

  Widget _buildSuperTextWithSelectionStaticSingle() {
    return _buildExampleContainer(
      child: SuperTextWithSelection.single(
        richText: _text,
        userSelection: const UserSelection(
          highlightStyle: _primaryHighlightStyle,
          caretStyle: _primaryCaretStyle,
          selection: TextSelection(baseOffset: 11, extentOffset: 21),
        ),
      ),
    );
  }

  Widget _buildSuperTextWithSelectionStaticMulti() {
    return _buildExampleContainer(
      child: SuperTextWithSelection.multi(
        richText: _text,
        userSelections: [
          const UserSelection(
            highlightStyle: _primaryHighlightStyle,
            caretStyle: _primaryCaretStyle,
            selection: TextSelection(baseOffset: 11, extentOffset: 21),
          ),
          UserSelection(
            highlightStyle: _johnHighlightStyle,
            caretStyle: _johnCaretStyle,
            selection: const TextSelection(baseOffset: 58, extentOffset: 65),
          ),
          UserSelection(
            highlightStyle: _sallyHighlightStyle,
            caretStyle: _sallyCaretStyle,
            selection: const TextSelection(baseOffset: 79, extentOffset: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCaret() {
    return _buildExampleContainer(
      child: SuperText(
        richText: _text,
        layerAboveBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: _primaryCaretStyle,
                  position: const TextPosition(offset: 21),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSingleSelectionHighlight() {
    return _buildExampleContainer(
      child: SuperText(
        richText: _text,
        layerAboveBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutCaret(
                  textLayout: textLayout,
                  style: _primaryCaretStyle,
                  position: const TextPosition(offset: 21),
                ),
              ],
            );
          },
        ),
        layerBeneathBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: _primaryHighlightStyle,
                  selection: const TextSelection(baseOffset: 11, extentOffset: 21),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSingleSelectionHighlightRainbow() {
    return _buildExampleContainer(
      child: SuperText(
        richText: _text,
        layerAboveBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                RainbowBuilder(builder: (context, color) {
                  return TextLayoutCaret(
                    textLayout: textLayout,
                    style: _primaryCaretStyle.copyWith(color: color),
                    position: const TextPosition(offset: 21),
                  );
                }),
              ],
            );
          },
        ),
        layerBeneathBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                RainbowBuilder(builder: (context, color) {
                  return TextLayoutSelectionHighlight(
                    textLayout: textLayout,
                    style: _primaryHighlightStyle.copyWith(color: color.withOpacity(0.2)),
                    selection: const TextSelection(baseOffset: 11, extentOffset: 21),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMultiUserSelections() {
    return _buildExampleContainer(
      child: SuperText(
        richText: _text,
        layerAboveBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return MultiLayerBuilder([
              (context, textLayout) {
                return Stack(
                  children: [
                    TextLayoutCaret(
                      textLayout: textLayout,
                      style: _primaryCaretStyle,
                      position: const TextPosition(offset: 21),
                    ),
                    TextLayoutCaret(
                      textLayout: textLayout,
                      style: _johnCaretStyle,
                      position: const TextPosition(offset: 65),
                    ),
                    TextLayoutCaret(
                      textLayout: textLayout,
                      style: _sallyCaretStyle,
                      position: const TextPosition(offset: 120),
                    ),
                  ],
                );
              },
              (context, textLayout) {
                return Stack(
                  children: [
                    TextLayoutUserLabel(
                      textLayout: textLayout,
                      style: _johnUserLabelStyle,
                      label: "John",
                      position: const TextPosition(offset: 65),
                    ),
                    TextLayoutUserLabel(
                      textLayout: textLayout,
                      style: _sallyUserLabelStyle,
                      label: "Sally",
                      position: const TextPosition(offset: 120),
                    ),
                  ],
                );
              },
            ]).build(context, textLayout);
          },
        ),
        layerBeneathBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return Stack(
              children: [
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: _primaryHighlightStyle,
                  selection: const TextSelection(baseOffset: 11, extentOffset: 21),
                ),
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: _johnHighlightStyle,
                  selection: const TextSelection(baseOffset: 58, extentOffset: 65),
                ),
                TextLayoutSelectionHighlight(
                  textLayout: textLayout,
                  style: _sallyHighlightStyle,
                  selection: const TextSelection(baseOffset: 79, extentOffset: 120),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySelection() {
    return _buildExampleContainer(
      child: SuperText(
        richText: const TextSpan(text: "", style: _textStyle),
        layerAboveBuilder: SuperDuperTextLayoutLayer(
          builder: (context, textLayout) {
            return TextLayoutEmptyHighlight(
              textLayout: textLayout,
              style: _primaryHighlightStyle,
            );
          },
        ),
      ),
    );
  }

  Widget _buildExampleContainer({
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.only(top: 20.0, bottom: 20.0, left: 16.0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(width: 5, color: Color(0xFFDDDDDD))),
      ),
      child: child,
    );
  }
}

class _TypingRobotExample extends StatefulWidget {
  const _TypingRobotExample({Key? key}) : super(key: key);

  @override
  _TypingRobotExampleState createState() => _TypingRobotExampleState();
}

class _TypingRobotExampleState extends State<_TypingRobotExample> {
  final _caretLink = LayerLink();
  late TextEditingController _controller;
  String _plainText = "";
  TextSpan _richText = const TextSpan(text: "", style: _textStyle);

  late TypingRobot _robot;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()
      ..addListener(() {
        if (_controller.text != _plainText && mounted) {
          setState(() {
            _plainText = _controller.text;
            _richText = TextSpan(text: _plainText, style: _textStyle);
          });
        }
      });

    _robot = TypingRobot(
      textEditingController: _controller,
    )
      ..placeCaret(const TextPosition(offset: 0))
      ..typeText(_textMessage)
      ..start();
  }

  @override
  void dispose() {
    _robot.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Building robot demo with follower");
    return Stack(
      children: [
        SuperTextWithSelection.single(
          richText: _richText,
          userSelection: UserSelection(
            highlightStyle: _primaryHighlightStyle,
            caretStyle: _primaryCaretStyle,
            selection: _controller.selection,
            caretFollower: _caretLink,
          ),
        ),
        _NextFrameBuilder(
          builder: (context) {
            return CompositedTransformFollower(
              link: _caretLink,
              followerAnchor: Alignment.centerLeft,
              targetAnchor: Alignment.centerRight,
              showWhenUnlinked: false,
              child: const UserLabel(
                label: "iRobot",
                style: UserLabelStyle(
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NextFrameBuilder extends StatefulWidget {
  const _NextFrameBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  final WidgetBuilder builder;

  @override
  _NextFrameBuilderState createState() => _NextFrameBuilderState();
}

class _NextFrameBuilderState extends State<_NextFrameBuilder> {
  Widget? _previousFrame;
  bool _isNextFrameBuild = false;

  @override
  Widget build(BuildContext context) {
    if (!_isNextFrameBuild) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {
          _isNextFrameBuild = true;
          _previousFrame = widget.builder(context);
        });
      });
    }
    _isNextFrameBuild = false;

    if (_previousFrame == null) {
      return const SizedBox();
    }

    return _previousFrame!;
  }
}

const defaultSelectionColor = Color(0xFFACCEF7);

const _textMessage =
    "Welcome to super_text, which provides a selection of text widgets that support custom carets, selection, and decoration.";

const _textStyle = TextStyle(
  color: Color(0xFF444444),
  fontFamily: 'Roboto',
  fontSize: 20,
  height: 1.4,
);

const _primaryCaretStyle = CaretStyle(
  width: 2.0,
  color: Colors.black,
);
const _primaryHighlightStyle = SelectionHighlightStyle(
  color: defaultSelectionColor,
);
const _johnCaretStyle = CaretStyle(
  width: 1.0,
  color: Colors.red,
);
final _johnHighlightStyle = SelectionHighlightStyle(
  color: Colors.red.withOpacity(0.5),
);
const _johnUserLabelStyle = UserLabelStyle(
  color: Colors.red,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    ),
  ),
);
const _sallyCaretStyle = CaretStyle(
  width: 2.0,
  color: Colors.purpleAccent,
);
final _sallyHighlightStyle = SelectionHighlightStyle(
  color: Colors.purpleAccent.withOpacity(0.5),
);
const _sallyUserLabelStyle = UserLabelStyle(
  color: Colors.purpleAccent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    ),
  ),
);
