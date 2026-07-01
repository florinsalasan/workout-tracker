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
            mainAxisSize: MainAxisSize.max,
            children: [
              // Title row — always visible
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
              const SizedBox(height: 4),
              // Exercise list — fills remaining space and clips cleanly
              Expanded(
                child: _ExerciseList(exercises: template.exercises),
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

// Renders as many exercise names as fit in the available height,
// then shows "+N more" if any were clipped.
class _ExerciseList extends StatelessWidget {
  final List<CompletedExercise> exercises;

  const _ExerciseList({required this.exercises});

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final countStyle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        // Measure line heights using a TextPainter so we know how many fit.
        double usedHeight = 0;
        int visibleCount = 0;

        // Account for the "Exercises: N" count line first.
        final countPainter = TextPainter(
          text: TextSpan(text: 'Exercises: ${exercises.length}', style: countStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        usedHeight += countPainter.height + 2; // 2px row gap

        // Then try to fit each exercise name.
        for (int i = 0; i < exercises.length; i++) {
          final painter = TextPainter(
            text: TextSpan(text: exercises[i].name, style: textStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);

          final lineHeight = painter.height + 2;
          final remaining = exercises.length - i;

          // If this is not the last exercise, reserve room for a "+N more" line.
          final needsOverflowLine = remaining > 1;
          final overflowLineHeight = needsOverflowLine ? lineHeight : 0;

          if (usedHeight + lineHeight + overflowLineHeight > maxHeight) {
            // Can't fit this line — stop here.
            break;
          }

          usedHeight += lineHeight;
          visibleCount++;
        }

        final hiddenCount = exercises.length - visibleCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exercises: ${exercises.length}',
              style: countStyle,
            ),
            for (int i = 0; i < visibleCount; i++)
              Text(
                exercises[i].name,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (hiddenCount > 0)
              Text(
                '+$hiddenCount more',
                style: textStyle,
              ),
          ],
        );
      },
    );
  }
}
