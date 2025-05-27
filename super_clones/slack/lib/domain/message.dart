import 'package:super_editor/super_editor.dart';

class Message {
  Message({
    required this.userId,
    required this.sentAt,
    required this.content,
  });
  final String userId;
  final DateTime sentAt;
  final Document content;
}
