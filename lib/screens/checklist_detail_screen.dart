import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/checklist_item.dart';
import '../providers/checklist_provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../widgets/global_app_bar.dart';

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
                HapticFeedback.lightImpact();
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
                HapticFeedback.lightImpact();
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
              appBar: GlobalAppBar(
                title: Text(group.title),
                actions: [
                  if (_showResetButton)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        HapticFeedback.lightImpact();
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
                  : ReorderableListView(
                padding:
                const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
                      onReorder: (oldIndex, newIndex) {
                        // Adjust the newIndex if it is greater than the oldIndex
                        if (newIndex > oldIndex) {
                          newIndex--;
                        }
                        // Update the provider with the new order
                        provider.reorderItems(
                            widget.groupId, oldIndex, newIndex);
                      },
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        return Slidable(
                          direction: Axis.horizontal,
                          key: ValueKey(item.id),
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                               SlidableAction(
                                 onPressed: (context) {
                                   HapticFeedback.lightImpact();
                                   _showEditItemDialog(context, item);
                                 },
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
                                   HapticFeedback.lightImpact();
                                   final removedItem =
                                       item; // Store the removed item
                                   provider.removeItem(widget.groupId, item.id);
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(
                                       content: Text('${item.title} deleted'),
                                       action: SnackBarAction(
                                         label: 'Undo',
                                         onPressed: () {
                                           HapticFeedback.lightImpact();
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
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.isCompleted
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.toggleItem(widget.groupId, item.id);
                                _checkCompletion(context, provider);
                              },
                            ),
                          ),
                        );
                      }),
                    ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddItemDialog(context);
                },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            onTap: () => HapticFeedback.lightImpact(),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Enter item name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogContext).pop();
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (controller.text.trim().isNotEmpty) {
                      Provider.of<ChecklistProvider>(context, listen: false)
                          .addItem(widget.groupId, controller.text.trim());
                      setState(() {
                        _showResetButton = false;
                      });
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.post_add, color: Colors.blueAccent),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (controller.text.trim().isNotEmpty) {
                      Provider.of<ChecklistProvider>(context, listen: false)
                          .addItem(widget.groupId, controller.text.trim());
                      setState(() {
                        _showResetButton = false;
                      });
                      Navigator.of(dialogContext).pop();
                      // Reopen the dialog to add another item
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showAddItemDialog(context);
                      });
                    }
                  },
                ),
              ],
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
    final focusNode = FocusNode(debugLabel: 'EditItemDialog');

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Item', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          onTap: () => HapticFeedback.lightImpact(),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter new item name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(dialogContext).pop();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blueAccent),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (controller.text.trim().isNotEmpty) {
                Provider.of<ChecklistProvider>(dialogContext, listen: false)
                    .updateItem(
                        widget.groupId,
                        ChecklistItem(
                          id: item.id,
                          title: controller.text.trim(),
                          isCompleted: item.isCompleted,
                        ));
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ],
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.dispose();
        controller.dispose();
      });
    });
  }
}
