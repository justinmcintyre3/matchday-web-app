import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            provider.removeItem(widget.groupId, item.id);
                          },
                          child: CheckboxListTile(
                            value: item.isCompleted,
                            onChanged: (bool? value) {
                              provider.toggleItem(widget.groupId, item.id);
                              _checkCompletion(context, provider);
                            },
                            title: Text(item.title),
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
}
