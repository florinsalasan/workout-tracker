import 'package:flutter/cupertino.dart';
import '../services/db_helpers.dart';
import '../services/exercise_visual_service.dart';

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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final slug = ExerciseVisualService.instance.getSlugForExercise(exercise.name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: Border(
            bottom: BorderSide(color: CupertinoColors.separator),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.systemGrey6.darkColor
                    : CupertinoColors.systemGrey6.color,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: slug != null
                  ? ExerciseVisualService.instance.buildFrameWidget(
                      slug: slug,
                      frameIndex: 1,
                      tintColor: isDark ? CupertinoColors.white : CupertinoColors.black,
                    )
                  : const Icon(
                      CupertinoIcons.sportscourt,
                      size: 22,
                      color: CupertinoColors.systemGrey,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                exercise.name,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }
}
