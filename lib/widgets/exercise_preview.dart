import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../services/db_helpers.dart';

class ExercisePreview extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const ExercisePreview({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: const Border(
            bottom: BorderSide(color: CupertinoColors.separator),
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
