import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/checklist_item.dart';
import '../providers/checklist_provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class ChecklistDetailScreen extends StatefulWidget {
  final String groupId;

  const ChecklistDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<ChecklistDetailScreen> createState() => _ChecklistDetailScreenState();
}

class _ChecklistDetailScreenState extends State<ChecklistDetailScreen> {
  late ConfettiController _confettiController;
  bool _showResetButton = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    // Check initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChecklistProvider>(context, listen: false);
      final items = provider.getItems(widget.groupId);
      final allCompleted =
          items.isNotEmpty && items.every((item) => item.isCompleted);
      setState(() {
        _showResetButton = allCompleted;
      });
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkCompletion(BuildContext context, ChecklistProvider provider) {
    final items = provider.getItems(widget.groupId);
    final allCompleted =
        items.isNotEmpty && items.every((item) => item.isCompleted);

    if (allCompleted) {
      _confettiController.play();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations! 🎉'),
          content: const Text(
              'You\'ve completed all items! Would you like to reset the checklist?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _showResetButton =
                      true; // Only show reset button if user chooses "Not Now"
                });
              },
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () {
                provider.resetGroup(widget.groupId);
                setState(() {
                  _showResetButton =
                      false; // Don't show reset button if user chooses to reset
                });
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _showResetButton = false; // Hide reset button if any item is unchecked
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChecklistProvider>(
      builder: (context, provider, child) {
        final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
        final items = provider.getItems(widget.groupId);

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(group.title),
                actions: [
                  if (_showResetButton)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        provider.resetGroup(widget.groupId);
                        setState(() {
                          _showResetButton = false;
                        });
                      },
                    ),
                ],
              ),
              body: items.isEmpty
                  ? const Center(
                      child: Text('No items yet. Add one below!'),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Slidable(
                          direction: Axis.horizontal,
                          key: ValueKey(item.id),
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) =>
                                    _showEditItemDialog(context, item),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Edit',
                              ),
                            ],
                          ),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  final removedItem =
                                      item; // Store the removed item
                                  provider.removeItem(widget.groupId, item.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${item.title} deleted'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () {
                                          provider.addItem(widget.groupId,
                                              removedItem.title);
                                        },
                                      ),
                                    ),
                                  );
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(
                              item.title,
                              style: TextStyle(
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isCompleted
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                            onTap: () {
                              provider.toggleItem(widget.groupId, item.id);
                              _checkCompletion(context, provider);
                            },
                          ),
                        );
                      },
                    ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _showAddItemDialog(context),
                child: const Icon(Icons.add),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final controller = TextEditingController();
    final focusNode = FocusNode(debugLabel: 'AddItemDialog');

    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          focusNode.unfocus();
        },
        child: AlertDialog(
          title: const Text('Add Item'),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter item name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Provider.of<ChecklistProvider>(context, listen: false)
                      .addItem(widget.groupId, controller.text);
                  setState(() {
                    _showResetButton =
                        false; // Hide reset button when new item is added
                  });
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.dispose();
        controller.dispose();
      });
    });
  }

  Future<void> _showEditItemDialog(
      BuildContext context, ChecklistItem item) async {
    final controller = TextEditingController(text: item.title);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new item name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Create a new ChecklistItem with the updated title
                final updatedItem = ChecklistItem(
                  id: item.id,
                  title: controller.text, // New title
                  isCompleted: item.isCompleted,
                );

                // Update the item in the provider's list
                Provider.of<ChecklistProvider>(context, listen: false)
                    .updateItem(widget.groupId, updatedItem);

                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
