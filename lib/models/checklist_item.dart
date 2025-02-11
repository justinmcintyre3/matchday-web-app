class ChecklistItem {
  final String id;
  final String title;
  bool isCompleted;

  ChecklistItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'],
    title: json['title'],
    isCompleted: json['isCompleted'],
  );
}