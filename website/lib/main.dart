import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003F51),
      body: Scrollbar(
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 18,
              height: 27 / 18,
              color: Colors.white.withOpacity(0.9),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/background.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      const _Header(),
                      const SizedBox(height: 52),
                      const _Editor(),
                      const SizedBox(height: 135),
                      const _Features(),
                      const _CallToAction(),
                      const _Footer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor();

  @override
  __EditorState createState() => __EditorState();
}

class __EditorState extends State<_Editor> {
  Document _doc;
  DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc);
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  static Document _createInitialDocument() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'A supercharged rich text\neditor for Flutter',
          ),
          metadata: {
            'blockType': 'header1',
            'textAlign': 'center',
          },
        ),
      ],
    );
  }

  static TextStyle _textStyleBuilder(Set<dynamic> attributions) {
    var result = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 18,
      height: 27 / 18,
      color: const Color(0xFF003F51).withOpacity(0.9),
    );

    for (final attribution in attributions) {
      if (attribution is! String) {
        continue;
      }

      switch (attribution) {
        case 'header1':
          result = result.copyWith(
            fontSize: 68,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
          break;
        case 'header2':
          result = result.copyWith(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            height: 1.2,
          );
          break;
        case 'blockquote':
          result = result.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
            color: Colors.grey,
          );
          break;
        case 'bold':
          result = result.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'italics':
          result = result.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'strikethrough':
          result = result.copyWith(decoration: TextDecoration.lineThrough);
          break;
      }
    }
    return result;
  }

  static Widget _centeredHeaderBuilder(ComponentContext context) {
    var result = paragraphBuilder(context);
    final node = context.documentNode;

    if (node is ParagraphNode) {
      if (node.metadata['blockType'] == 'header1') {
        return Center(child: result);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 800).tighten(height: 622),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Editor.custom(
          editor: _docEditor,
          maxWidth: 800,
          padding: const EdgeInsets.all(32),
          textStyleBuilder: _textStyleBuilder,
          componentBuilders: [
            _centeredHeaderBuilder,
            ...defaultComponentBuilders,
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1112),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/logo.gif',
            width: 188,
            height: 44,
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 16,
              color: Colors.white,
            ),
            child: Row(
              children: [
                Text('Github'),
                const SizedBox(width: 26),
                Text('Docs'),
                const SizedBox(width: 26),
                _SmallButton(child: Text('Download')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureThingy extends StatelessWidget {
  const _FeatureThingy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF053239),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(24),
          child: Image.asset(
            'assets/ic_customize.png',
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fully customizable',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 38,
            height: 46 / 38,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Easy to extend and very detailed access to all component, designed to and build for developer, allow you to adjust the editor to your specific needs',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  _SmallButton({@required this.child}) : assert(child != null);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          height: 1.4,
          color: const Color(0xFF0D2C3A),
        ),
        child: child,
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  _BigButton({@required this.child}) : assert(child != null);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 29,
          height: 1.26,
          color: const Color(0xFF0D2C3A),
        ),
        child: child,
      ),
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF14AEBE),
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 76),
          Text(
            'Get started with SuperEditor',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 51,
              height: 61 / 51,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 29),
          _BigButton(child: Text('Download now')),
          const SizedBox(height: 104),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 1112),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sponsored by the Superlist Team'),
                const SizedBox(height: 6),
                Text(
                  'Superlist is building a new task manager for individuals and teams and we\'re doing it all in Flutter. Join us',
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keep up to date:'),
              const SizedBox(height: 4),
              Text('Twitter'),
              const SizedBox(height: 4),
              Text('Superlist.com'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF003F51),
      padding: const EdgeInsets.only(bottom: 80),
      child: Transform.translate(
        offset: Offset(0, -49),
        child: Center(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1112),
                child: Row(
                  children: [
                    Expanded(child: const _FeatureThingy()),
                    const SizedBox(width: 24),
                    Expanded(child: const _FeatureThingy()),
                  ],
                ),
              ),
              const SizedBox(height: 117),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 544),
                child: Column(
                  children: [
                    Text(
                      'other great things about this babyyyyyyyyyy',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 38,
                        height: 46 / 38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 37),
                    SizedBox(
                      width: 544,
                      height: 307,
                      child: Placeholder(),
                    ),
                    const SizedBox(height: 31),
                    Text(
                      'Lorem ipsum home school stay-at-home order Blursday. Staycation stimulus essential. Dr. Fauci remote learning WHO isolation mail-in vote. Virtual happy hour Quibi four seasons total landscaping monolith home office.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
