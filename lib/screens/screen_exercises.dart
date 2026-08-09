import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../widgets/sliver_layout.dart';
import '../widgets/exercise_details_view.dart';
import '../services/db_helpers.dart';
import '../utils/fuzzy_match.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ExercisesScreenState createState() => ExercisesScreenState();
}

class ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Tags loaded from DB: each entry is {'id': int, 'name': String}.
  List<Map<String, dynamic>> _allTags = [];

  /// Currently selected tag IDs for filtering.
  final Set<int> _selectedTagIds = {};

  /// Exercise IDs that match the currently selected tags.
  /// null = no tag filter active (show all).
  Set<int>? _tagFilteredIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExerciseProvider>(context, listen: false).loadExercises();
      _loadTags();
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

  Future<void> _loadTags() async {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    final tags = await provider.getAllTags();
    if (!mounted) return;
    setState(() => _allTags = tags);
  }

  Future<void> _onTagToggled(int tagId) async {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });

    if (_selectedTagIds.isEmpty) {
      setState(() => _tagFilteredIds = null);
      return;
    }

    // Intersect exercise IDs across all selected tags (AND filter).
    Set<int>? result;
    for (final id in _selectedTagIds) {
      final ids = await provider.getExerciseIdsByTag(id);
      result = result == null ? ids : result.intersection(ids);
    }
    if (!mounted) return;
    setState(() => _tagFilteredIds = result ?? {});
  }

  List<Exercise> _filterExercises(List<Exercise> exercises) {
    return exercises.where((exercise) {
      // Tag filter
      if (_tagFilteredIds != null && !_tagFilteredIds!.contains(exercise.id)) {
        return false;
      }
      // Search filter
      if (_searchQuery.isNotEmpty && !fuzzyMatch(exercise.name, _searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _navigateToExerciseDetails(Exercise exercise) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExerciseDetailsView(exercise: exercise),
      ),
    );
    // Refresh tags in case any were created/modified in the detail view
    await _loadTags();
  }

  void _showDeleteConfirmation(BuildContext context, Exercise exercise) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text(
            'Are you sure you want to delete ${exercise.name}? This will not remove past workout data, but it will hide the exercise.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              Provider.of<ExerciseProvider>(context, listen: false)
                  .deleteExercise(exercise.id!);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Tag management ──────────────────────────────────────────────────────────

  void _showManageTagsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ManageTagsSheet(
        allTags: _allTags,
        onTagCreated: (name) async {
          final provider =
              Provider.of<ExerciseProvider>(context, listen: false);
          await provider.addTag(name);
          await _loadTags();
        },
        onTagDeleted: (tagId) async {
          final provider =
              Provider.of<ExerciseProvider>(context, listen: false);
          await provider.deleteTag(tagId);
          _selectedTagIds.remove(tagId);
          await _loadTags();
          // Recompute filter
          if (_selectedTagIds.isEmpty) {
            setState(() => _tagFilteredIds = null);
          } else {
            await _onTagToggled(_selectedTagIds.first); // retrigger
          }
        },
      ),
    );
  }

  void _showTagExerciseSheet(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _TagExerciseSheet(
        exercise: exercise,
        allTags: _allTags,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Exercises',
      body: Consumer<ExerciseProvider>(
        builder: (context, exerciseProvider, child) {
          if (exerciseProvider.exercises.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _filterExercises(exerciseProvider.exercises);

          return Column(
            children: [
              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
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
              // ── Tag filter chips ────────────────────────────────────────
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    // Scrollable tag chips
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 12),
                        children: _allTags.map((tag) {
                          final tagId = tag['id'] as int;
                          final tagName = tag['name'] as String;
                          final isSelected = _selectedTagIds.contains(tagId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(tagName),
                              selected: isSelected,
                              onSelected: (_) => _onTagToggled(tagId),
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              checkmarkColor: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Sticky manage button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.sell_outlined, size: 18),
                        label: const Text('Manage Tags'),
                        onPressed: _showManageTagsSheet,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Results count ───────────────────────────────────────────
              if (_searchQuery.isNotEmpty || _selectedTagIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filtered.length} exercise${filtered.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              // ── Exercise list ───────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
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
                              if (_searchQuery.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    final name = _searchQuery.trim();
                                    final provider =
                                        Provider.of<ExerciseProvider>(
                                            context,
                                            listen: false);
                                    await provider.addExercise(Exercise(
                                        name: name, isCustom: true));
                                    _searchController.clear();
                                  },
                                  child: Text(
                                      'Create "${_searchQuery.trim()}"'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                exercise.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () =>
                                  _navigateToExerciseDetails(exercise),
                              onLongPress: () =>
                                  _showTagExerciseSheet(exercise),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Manage Tags Bottom Sheet ──────────────────────────────────────────────────

class _ManageTagsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allTags;
  final Future<void> Function(String tagName) onTagCreated;
  final Future<void> Function(int tagId) onTagDeleted;

  const _ManageTagsSheet({
    required this.allTags,
    required this.onTagCreated,
    required this.onTagDeleted,
  });

  @override
  State<_ManageTagsSheet> createState() => _ManageTagsSheetState();
}

class _ManageTagsSheetState extends State<_ManageTagsSheet> {
  final TextEditingController _tagSearchController = TextEditingController();
  String _tagSearchQuery = '';
  late List<Map<String, dynamic>> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.allTags);
    _tagSearchController.addListener(() {
      setState(() => _tagSearchQuery = _tagSearchController.text);
    });
  }

  @override
  void dispose() {
    _tagSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_tagSearchQuery.isEmpty) return _tags;
    return _tags
        .where((t) => fuzzyMatch(t['name'] as String, _tagSearchQuery))
        .toList();
  }

  bool get _exactMatchExists {
    final query = _tagSearchQuery.trim().toLowerCase();
    return _tags.any((t) => (t['name'] as String).toLowerCase() == query);
  }

  Future<void> _createTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await widget.onTagCreated(trimmed);
    _tagSearchController.clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTags;
    final trimmedQuery = _tagSearchQuery.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Manage Tags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Search & Add tag field ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search or add tag...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _tagSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _tagSearchController.clear(),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty && !_exactMatchExists) {
                          _createTag(val);
                        }
                      },
                    ),
                  ),
                  if (trimmedQuery.isNotEmpty && !_exactMatchExists) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _createTag(trimmedQuery),
                      child: const Text('Add'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Tag list ──
            if (_tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No tags created yet. Type a name above to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'No matching tags',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (trimmedQuery.isNotEmpty && !_exactMatchExists) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => _createTag(trimmedQuery),
                        child: Text('Create "$trimmedQuery"'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tag = filtered[index];
                    final tagId = tag['id'] as int;
                    final tagName = tag['name'] as String;
                    return ListTile(
                      dense: true,
                      title: Text(tagName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () async {
                          await widget.onTagDeleted(tagId);
                          setState(() {
                            _tags.removeWhere((t) => t['id'] == tagId);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Tag Exercise Bottom Sheet ─────────────────────────────────────────────────

class _TagExerciseSheet extends StatefulWidget {
  final Exercise exercise;
  final List<Map<String, dynamic>> allTags;

  const _TagExerciseSheet({
    required this.exercise,
    required this.allTags,
  });

  @override
  State<_TagExerciseSheet> createState() => _TagExerciseSheetState();
}

class _TagExerciseSheetState extends State<_TagExerciseSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _exerciseTags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExerciseTags();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExerciseTags() async {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    final tags = await provider.getExerciseTags(widget.exercise.id!);
    if (!mounted) return;
    setState(() {
      _exerciseTags = tags;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_searchQuery.isEmpty) return widget.allTags;
    return widget.allTags
        .where((t) => fuzzyMatch(t['name'] as String, _searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTags;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tags for ${widget.exercise.name}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (widget.allTags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tags created yet. Use "Manage Tags" to create tags first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              if (widget.allTags.length > 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter tags...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No matching tags',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tag = filtered[index];
                      final tagId = tag['id'] as int;
                      final tagName = tag['name'] as String;
                      final isAssigned = _exerciseTags.contains(tagName);

                      return CheckboxListTile(
                        dense: true,
                        title: Text(tagName),
                        value: isAssigned,
                        onChanged: (checked) async {
                          final provider = Provider.of<ExerciseProvider>(
                              context,
                              listen: false);
                          if (checked == true) {
                            await provider.addTagToExercise(
                                widget.exercise.id!, tagId);
                          } else {
                            await provider.removeTagFromExercise(
                                widget.exercise.id!, tagId);
                          }
                          await _loadExerciseTags();
                        },
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
