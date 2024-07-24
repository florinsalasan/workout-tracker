import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/providers/history_provider.dart';

import '../models/workout_model.dart';

class TemplatePreviewCard extends StatelessWidget {
  final CompletedWorkout template;
  final int templateId;
  final String name;
  final VoidCallback onTap;

  const TemplatePreviewCard({
    super.key,
    required this.template,
    required this.templateId,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoContextMenu(
      enableHapticFeedback: true,
      actions: <Widget>[
        CupertinoContextMenuAction(
          onPressed: () {
            _renameTemplate(context);
            // Navigator.pop(context);
          },
          child: const Text(
            'Rename Template',
          ),
        ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.delete,
          isDestructiveAction: true,
          onPressed: () {
            _removeTemplate(context);
            // Navigator.pop(context);
          },
          child: const Text(
            'Delete Template',
          ),
        ),
      ],
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CupertinoColors.systemGrey4),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Number of Exercises: ${template.exercises.length}',
                style: const TextStyle(fontSize: 14),
              ),
              ...template.exercises.take(3).map((exercise) => Text(
                    exercise.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
              if (template.exercises.length > 3)
                const Text(
                  "...",
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeTemplate(BuildContext context) async {
    final historyProvider =
        Provider.of<HistoryProvider>(context, listen: false);

    // Show a confirmation dialog
    final bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await historyProvider.deleteTemplate(templateId);
    }
  }

  void _renameTemplate(BuildContext context) async {
    final historyProvider =
        Provider.of<HistoryProvider>(context, listen: false);
    String newName = name;

    // Show a dialog to input the new name
    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Rename Template'),
        content: CupertinoTextField(
          controller: TextEditingController(text: name),
          onChanged: (value) => newName = value,
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              await historyProvider.renameTemplate(templateId, newName);
              Navigator.of(context).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
