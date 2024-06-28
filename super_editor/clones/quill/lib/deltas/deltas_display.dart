import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:feather/infrastructure/super_editor_extensions.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/super_editor_quill.dart';

class DeltasDisplay extends StatefulWidget {
  const DeltasDisplay({
    super.key,
    required this.editor,
  });

  final Editor editor;

  @override
  State<DeltasDisplay> createState() => _DeltasDisplayState();
}

class _DeltasDisplayState extends State<DeltasDisplay> implements EditListener {
  Delta? _delta;

  @override
  void initState() {
    super.initState();
    widget.editor.addListener(this);

    onEdit([]);
  }

  @override
  void didUpdateWidget(DeltasDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor) {
      oldWidget.editor.removeListener(this);
      widget.editor.addListener(this);
    }
  }

  @override
  void dispose() {
    widget.editor.removeListener(this);
    super.dispose();
  }

  @override
  void onEdit(List<EditEvent> changeList) {
    setState(() {
      _delta = widget.editor.document.toQuillDeltas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF333333),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _delta!.operations.length,
        itemBuilder: (context, index) {
          final op = _delta!.operations[index];
          final data = op.data;

          final buffer = StringBuffer();
          if (op.isInsert) {
            buffer.write("Insert: ");
          } else if (op.isRetain) {
            buffer.write("Retain: ");
          } else if (op.isDelete) {
            buffer.write("Delete: ");
          }

          if (data is String) {
            buffer.write("'${data.replaceAll("\n", "⏎")}'");
          } else {
            buffer.write(data);
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  buffer.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "Monospace",
                  ),
                ),
                if (op.attributes != null)
                  Text(
                    op.attributes!.entries.map((entry) => "${entry.key}: ${entry.value}").join(", ") ?? "",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: "Monospace",
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
