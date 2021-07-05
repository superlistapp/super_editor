class Task {
  const Task({
    required this.id,
    required this.checked,
    required this.text,
  });

  final String id;
  final bool checked;
  final String text;

  Task copyWith({
    String? id,
    bool? checked,
    String? text,
    int? indent,
  }) {
    return Task(
      id: id ?? this.id,
      checked: checked ?? this.checked,
      text: text ?? this.text,
    );
  }
}
