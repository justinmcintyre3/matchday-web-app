import 'package:matchday/models/checklist_item.dart';

class ChecklistGroup {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChecklistItem> itemList;

  ChecklistGroup({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.itemList,
  });

  factory ChecklistGroup.fromJson(Map<String, dynamic> json) {
    return ChecklistGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      itemList: [], // Initialize empty, items loaded separately
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}