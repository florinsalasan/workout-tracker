import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/strong_import_models.dart';
import '../providers/exercise_provider.dart';
import '../providers/history_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/strong_import_service.dart';

class StrongImportDialog extends StatefulWidget {
  final StrongImportService? importService;
  final StrongImportSummary? initialSummary;

  const StrongImportDialog({super.key, this.importService, this.initialSummary});

  static Future<void> show(BuildContext context, {StrongImportService? importService}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StrongImportDialog(importService: importService),
    );
  }

  @override
  State<StrongImportDialog> createState() => _StrongImportDialogState();
}

enum _ImportStep {
  initial,
  parsing,
  preview,
  importing,
  complete,
  error,
}

class _StrongImportDialogState extends State<StrongImportDialog> {
  late final StrongImportService _service;
  late _ImportStep _step;
  String? _errorMessage;

  String? _selectedFileName;
  StrongImportSummary? _summary;
  StrongImportResult? _result;

  int _currentProgress = 0;
  int _totalProgress = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.importService ?? StrongImportService();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      _step = _ImportStep.preview;
    } else {
      _step = _ImportStep.initial;
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (files.isEmpty) {
        return;
      }

      final file = files.first;
      _selectedFileName = file.name;
      setState(() {
        _step = _ImportStep.parsing;
        _errorMessage = null;
      });

      final content = await file.xFile.readAsString();

      final unit = UserPreferences().weightUnit;
      final summary = await _service.prepareImport(content, fallbackWeightUnit: unit);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _step = _ImportStep.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to read Strong CSV: $e';
        _step = _ImportStep.error;
      });
    }
  }

  Future<void> _startImport() async {
    final summary = _summary;
    if (summary == null) return;

    setState(() {
      _step = _ImportStep.importing;
      _currentProgress = 0;
      _totalProgress = summary.workouts.length;
    });

    try {
      final result = await _service.executeImport(
        summary,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentProgress = current;
              _totalProgress = total;
            });
          }
        },
      );

      // Refresh providers so app immediately shows new workouts and custom exercises
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);

        historyProvider.refreshHistory();
        await exerciseProvider.loadExercises();

        setState(() {
          _result = result;
          _step = _ImportStep.complete;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Import encountered an error: $e';
        _step = _ImportStep.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sync_alt,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import from Strong',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Migrate your historical workouts & sets',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Body based on step
              _buildStepContent(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, ThemeData theme) {
    switch (_step) {
      case _ImportStep.initial:
        return _buildInitialStep(context, theme);
      case _ImportStep.parsing:
        return _buildLoadingStep(context, theme, 'Analyzing Strong export...');
      case _ImportStep.preview:
        return _buildPreviewStep(context, theme);
      case _ImportStep.importing:
        return _buildImportingStep(context, theme);
      case _ImportStep.complete:
        return _buildCompleteStep(context, theme);
      case _ImportStep.error:
        return _buildErrorStep(context, theme);
    }
  }

  Widget _buildInitialStep(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to export from Strong:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildBullet('1. Open Strong and tap the Profile / Settings tab.'),
              _buildBullet('2. Select "Export Data" and choose "Strong CSV".'),
              _buildBullet('3. Save or AirDrop the file and pick it below.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Select Strong CSV File', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _pickFile,
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, height: 1.3),
      ),
    );
  }

  Widget _buildLoadingStep(BuildContext context, ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(BuildContext context, ThemeData theme) {
    final summary = _summary!;
    final earliest = summary.earliestDate;
    final latest = summary.latestDate;
    final dateRangeStr = (earliest != null && latest != null)
        ? '${DateFormat('MMM d, yyyy').format(earliest)} – ${DateFormat('MMM d, yyyy').format(latest)}'
        : 'Unknown range';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedFileName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedFileName!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Summary Card Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                Icons.fitness_center,
                'Workouts',
                '${summary.totalWorkouts}',
                subtitle: dateRangeStr,
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                Icons.repeat,
                'Total Sets',
                NumberFormat('#,###').format(summary.totalSets),
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                Icons.list_alt,
                'Exercises',
                '${summary.uniqueExerciseNames.length} distinct',
                subtitle: summary.newCustomExercisesToCreate.isEmpty
                    ? 'All exercises match existing catalog'
                    : '${summary.newCustomExercisesToCreate.length} new custom exercise(s) will be created',
              ),
              if (summary.duplicateWorkoutCount > 0) ...[
                const Divider(height: 20),
                _buildSummaryRow(
                  Icons.content_copy,
                  'Existing Duplicates',
                  '${summary.duplicateWorkoutCount} skipped',
                  subtitle: 'Workouts on the same date will not be duplicated',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _pickFile,
                child: const Text('Pick Another'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: summary.totalWorkouts > 0 ? _startImport : null,
                child: Text(
                  'Import ${summary.totalWorkouts} Workouts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value, {String? subtitle}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportingStep(BuildContext context, ThemeData theme) {
    final percent = _totalProgress > 0 ? (_currentProgress / _totalProgress).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Text(
            'Importing $_currentProgress of $_totalProgress workouts...',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Writing sessions and computing personal best milestones',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep(BuildContext context, ThemeData theme) {
    final result = _result!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Import Complete!',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Successfully imported ${result.workoutsImported} workouts and ${NumberFormat('#,###').format(result.setsImported)} sets.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        if (result.exercisesCreated > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Created ${result.exercisesCreated} custom exercise(s).',
            style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        if (result.skippedDuplicates > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Skipped ${result.skippedDuplicates} duplicate workout(s).',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStep(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Import Error',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'An unexpected error occurred.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.tonal(
            onPressed: () {
              setState(() {
                _step = _ImportStep.initial;
                _errorMessage = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ),
      ],
    );
  }
}
