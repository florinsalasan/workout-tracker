import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/sliver_layout.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: UserPreferences(),
      child: CustomLayout(
        title: 'Profile and Settings',
        body: Consumer<UserPreferences>(
          builder: (context, userPreferences, child) {
            return SafeArea(
              child: ListView(
                children: [
                  _buildSettingsGroup(
                    'Units',
                    [
                      _buildUnitSetting(
                        'Weight Units',
                        userPreferences.weightUnit,
                        (String? newValue) {
                          if (newValue != null) {
                            userPreferences.setWeightUnit(newValue);
                          }
                        },
                        ['kg', 'lbs'],
                      ),
                      const Divider(height: 1),
                      _buildUnitSetting(
                        'Height Units',
                        userPreferences.heightUnit,
                        (String? newValue) {
                          if (newValue != null) {
                            userPreferences.setHeightUnit(newValue);
                          }
                        },
                        ['cm', 'ft'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsGroup(
                    'Personal Information',
                    [
                      _buildHeightDisplay(context, userPreferences),
                      const Divider(height: 1),
                      _buildWeightDisplay(context, userPreferences),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSetting(
    String title,
    String currentValue,
    void Function(String?) onChanged,
    List<String> options,
  ) {
    return ListTile(
      title: Text(title),
      trailing: SegmentedButton<String>(
        showSelectedIcon: false, 
        segments: options.map((String option) {
          return ButtonSegment<String>(
            value: option,
            label: Text(option),
          );
        }).toList(),
        selected: {currentValue},
        onSelectionChanged: (Set<String> newSelection) {
          onChanged(newSelection.first);
        },
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildWeightDisplay(BuildContext context, UserPreferences userPreferences) {
    return ListTile(
      title: const Text('Weight'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${userPreferences.displayWeight.toStringAsFixed(1)} ${userPreferences.weightUnit}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit, size: 20, color: Colors.grey),
        ],
      ),
      onTap: () => _showWeightDialog(context, userPreferences), 
    );
  }

  Widget _buildHeightDisplay(BuildContext context, UserPreferences userPreferences) {
    String displayHeight;
    if (userPreferences.heightUnit == 'cm') {
      displayHeight = '${userPreferences.displayHeight.toStringAsFixed(1)} cm';
    } else {
      final feet = (userPreferences.displayHeight / 12).floor();
      final inches = (userPreferences.displayHeight % 12).round();
      displayHeight = '$feet\' $inches"';
    }

    return ListTile(
      title: const Text('Height'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayHeight,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit, size: 20, color: Colors.grey),
        ],
      ),
      onTap: () => _showHeightDialog(context, userPreferences),
    );
  }

  void _showWeightDialog(BuildContext context, UserPreferences userPreferences) {
    final controller = TextEditingController(
      text: userPreferences.displayWeight > 0 ? userPreferences.displayWeight.toStringAsFixed(1) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight',
            hintText: 'e.g., 190',
            suffixText: userPreferences.weightUnit,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final weight = double.tryParse(controller.text);
              if (weight != null) {
                userPreferences.saveWeightFromUI(weight); 
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHeightDialog(BuildContext context, UserPreferences userPreferences) {
    final isCm = userPreferences.heightUnit == 'cm';
    
    final cmController = TextEditingController(
      text: userPreferences.displayHeight > 0 ? userPreferences.displayHeight.toStringAsFixed(1) : '',
    );
    
    final feet = (userPreferences.displayHeight / 12).floor();
    final inches = (userPreferences.displayHeight % 12).round();
    
    final ftController = TextEditingController(text: feet > 0 ? feet.toString() : '');
    final inController = TextEditingController(text: inches > 0 ? inches.toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Height'),
        content: isCm 
          ? TextField(
              controller: cmController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Height',
                hintText: 'e.g., 180',
                suffixText: 'cm',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ftController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Feet',
                      hintText: 'e.g., 6',
                      suffixText: 'ft',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: inController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Inches',
                      hintText: 'e.g., 5',
                      suffixText: 'in',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (isCm) {
                final height = double.tryParse(cmController.text);
                if (height != null) userPreferences.saveHeightFromUI(height);
              } else {
                final f = int.tryParse(ftController.text) ?? 0;
                final i = int.tryParse(inController.text) ?? 0;
                userPreferences.saveHeightFromUI((f * 12 + i).toDouble());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
