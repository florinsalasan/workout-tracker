import 'package:flutter/material.dart';
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
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias, // Keeps the tap ripple inside the borders
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptionsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // A small visual indicator that there's a menu
                  GestureDetector(
                    onTap: () => _showOptionsSheet(context),
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Exercises: ${template.exercises.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              ...template.exercises.take(3).map((exercise) => Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
              if (template.exercises.length > 3)
                Text(
                  "...",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Material Bottom Sheet replacing the Cupertino Context Menu
  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename Template'),
                onTap: () {
                  Navigator.pop(bottomSheetContext); // Close sheet
                  _renameTemplate(context); // Open dialog
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Template',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext); // Close sheet
                  _removeTemplate(context); // Open dialog
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeTemplate(BuildContext context) async {
    final historyProvider =
        Provider.of<HistoryProvider>(context, listen: false);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Material way to make destructive text red
            ),
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
    final TextEditingController controller = TextEditingController(text: name);

    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename Template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Template Name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => newName = value,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            onPressed: () async {
              if (newName.trim().isNotEmpty) {
                await historyProvider.renameTemplate(templateId, newName.trim());
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
