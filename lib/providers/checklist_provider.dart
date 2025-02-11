import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:matchday/models/checklist_group.dart';
import 'package:matchday/models/checklist_item.dart';

class ChecklistProvider with ChangeNotifier {
  final SharedPreferences prefs;
  final List<ChecklistGroup> _groups = [];
  final Map<String, List<ChecklistItem>> _checklists = {};
  static const String _groupsKey = 'checklist_groups';
  static const String _itemsKeyPrefix = 'checklist_items_';

  ChecklistProvider(this.prefs) {
    _loadGroups();
  }

  List<ChecklistGroup> get groups => _groups;

  List<ChecklistItem> getItems(String groupId) => _checklists[groupId] ?? [];

  void _loadGroups() {
    final String? groupsString = prefs.getString(_groupsKey);
    if (groupsString != null) {
      final List<dynamic> decodedList = jsonDecode(groupsString);
      _groups
          .addAll(decodedList.map((group) => ChecklistGroup.fromJson(group)));

      // Load items for each group
      for (var group in _groups) {
        _loadItems(group.id);
      }
    }
    notifyListeners();
  }

  void _loadItems(String groupId) {
    final String? itemsString = prefs.getString('$_itemsKeyPrefix$groupId');
    if (itemsString != null) {
      final List<dynamic> decodedList = jsonDecode(itemsString);
      _checklists[groupId] =
          decodedList.map((item) => ChecklistItem.fromJson(item)).toList();
    } else {
      _checklists[groupId] = [];
    }
  }

  void addGroup(String title) {
    if (title.isNotEmpty) {
      final newGroup = ChecklistGroup(
        id: const Uuid().v4(),
        title: title,
        createdAt: DateTime.now(),
        itemList: [],
      );
      _groups.add(newGroup);
      _checklists[newGroup.id] = [];
      _saveGroups();
      notifyListeners();
    }
  }

  void deleteGroup(String groupId) {
    _groups.removeWhere((group) => group.id == groupId);
    _checklists.remove(groupId);
    prefs.remove('$_itemsKeyPrefix$groupId');
    _saveGroups();
    notifyListeners();
  }

  void restoreGroup(ChecklistGroup group) {
    _groups.add(group);
    _checklists[group.id] = group.itemList;
    _saveGroups();
    _saveItems(group.id);
    notifyListeners();
  }

  void addItem(String groupId, String title) {
    if (title.isNotEmpty) {
      final newItem = ChecklistItem(
        id: const Uuid().v4(),
        title: title,
        isCompleted: false,
      );
      _checklists[groupId]?.add(newItem);
      _saveItems(groupId);
      notifyListeners();
    }
  }

  void removeItem(String groupId, String itemId) {
    _checklists[groupId]?.removeWhere((item) => item.id == itemId);
    _saveItems(groupId);
    notifyListeners();
  }

  void toggleItem(String groupId, String itemId) {
    final item = _checklists[groupId]?.firstWhere((item) => item.id == itemId);
    if (item != null) {
      item.isCompleted = !item.isCompleted;
      _saveItems(groupId);
      notifyListeners();
    }
  }

  void _saveGroups() {
    final String encodedList =
        jsonEncode(_groups.map((group) => group.toJson()).toList());
    prefs.setString(_groupsKey, encodedList);
  }

  void _saveItems(String groupId) {
    final String encodedList =
        jsonEncode(_checklists[groupId]?.map((item) => item.toJson()).toList());
    prefs.setString('$_itemsKeyPrefix$groupId', encodedList);
  }

  bool isGroupCompleted(String groupId) {
    final items = _checklists[groupId] ?? [];
    return items.isNotEmpty && items.every((item) => item.isCompleted);
  }

  void resetGroup(String groupId) {
    final items = _checklists[groupId];
    if (items != null) {
      for (var item in items) {
        item.isCompleted = false;
      }
      _saveItems(groupId);
      notifyListeners();
    }
  }
}
