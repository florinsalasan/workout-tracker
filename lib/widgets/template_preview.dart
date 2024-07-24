import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/workout_model.dart';

class TemplatePreviewCard extends StatelessWidget {
  final CompletedWorkout template;
  final String name;
  final VoidCallback onTap;

  const TemplatePreviewCard({
    super.key,
    required this.template,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
              style: TextStyle(fontSize: 14),
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
    );
  }
}
