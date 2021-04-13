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
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ScrollController _scrollController;
  Document _doc;
  DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc);
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Scrollbar(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'A supercharged rich text editor for Flutter',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.red,
                          height: 320,
                          child: Editor.standard(
                            scrollController: _scrollController,
                            editor: _docEditor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 56, horizontal: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < 200; i++) ...[
                const SizedBox(height: 16),
                Text('blah blah blah blah blah blah blah blah blah blah blah')
              ]
            ],
          ),
        ),
      ),
    );
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: DocumentEditor.createNodeId(),
        imageUrl: 'https://picsum.photos/200/300',
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Try Me! I’m live!!!!',
        ),
        metadata: {
          'blockType': 'header1',
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Try typing here and editing this text.',
        ),
      ),
    ],
  );
}
