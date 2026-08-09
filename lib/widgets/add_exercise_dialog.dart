import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../services/db_helpers.dart';
import '../utils/fuzzy_match.dart';

class ExerciseSelectionDialog extends StatefulWidget {
  const ExerciseSelectionDialog({super.key});

  @override
  ExerciseSelectionDialogState createState() => ExerciseSelectionDialogState();
}

class ExerciseSelectionDialogState extends State<ExerciseSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExerciseProvider>(context, listen: false).loadExercises();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> _filterExercises(List<Exercise> exercises) {
    if (_searchQuery.isEmpty) return exercises;
    return exercises
        .where((e) => fuzzyMatch(e.name, _searchQuery))
        .toList();
  }

  Future<void> _showAddCustomExerciseDialog() async {
    final customController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Custom Exercise'),
        content: TextField(
          controller: customController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Exercise name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = customController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final exerciseProvider =
          Provider.of<ExerciseProvider>(context, listen: false);
      await exerciseProvider
          .addExercise(Exercise(name: result, isCustom: true));
      // Immediately select the newly created exercise
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Returning a Scaffold inside a showDialog automatically makes it a full-screen modal
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercise'),
        // Material standard is an 'X' close button on the left for modal dialogs
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showAddCustomExerciseDialog,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Custom'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            // ── Exercise list ─────────────────────────────────────────
            Expanded(
              child: Consumer<ExerciseProvider>(
                builder: (context, exerciseProvider, child) {
                  final filtered =
                      _filterExercises(exerciseProvider.exercises);

                  if (exerciseProvider.exercises.isEmpty) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No matching exercises',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _showAddCustomExerciseDialog,
                              child: Text(
                                  'Create "${_searchQuery.trim()}"'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return ListTile(
                        title: Text(exercise.name),
                        onTap: () =>
                            Navigator.of(context).pop(exercise.name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
