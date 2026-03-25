import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
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
                      _buildHeightSetting(userPreferences),
                      const Divider(height: 1),
                      _buildWeightSetting(userPreferences),
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
              color: Colors.blueAccent, // Matches the seed color we set earlier
            ),
          ),
        ),
        // Wrapping in a Material card gives it that elevated, grouped settings look
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

  Widget _buildHeightSetting(UserPreferences userPreferences) {
    if (userPreferences.heightUnit == 'cm') {
      return _buildCentimeterHeightField(userPreferences);
    } else {
      return _buildFeetInchesHeightField(userPreferences);
    }
  }

  Widget _buildWeightSetting(UserPreferences userPreferences) {
    return ListTile(
      title: const Text('Enter your weight:'),
      trailing: SizedBox(
        width: 120,
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    userPreferences.weightUnit,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            final weight = double.tryParse(value);
            if (weight != null) {
              userPreferences.setWeight(weight);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCentimeterHeightField(UserPreferences userPreferences) {
    return ListTile(
      title: const Text('Enter your height:'),
      trailing: SizedBox(
        width: 120,
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    userPreferences.heightUnit,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            final height = double.tryParse(value);
            if (height != null) {
              userPreferences.setHeight(height);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFeetInchesHeightField(UserPreferences userPreferences) {
    return ListTile(
      title: const Text('Enter your height:'),
      trailing: SizedBox(
        width: 160,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                suffixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        "ft",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
                onChanged: (value) {
                  final feet = int.tryParse(value);
                  if (feet != null) {
                    final inches = userPreferences.height % 12;
                    userPreferences.setHeight(feet * 12 + inches);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                suffixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        "in",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
                onChanged: (value) {
                  final inches = int.tryParse(value);
                  if (inches != null) {
                    final feet = (userPreferences.height / 12).floor();
                    userPreferences.setHeight((feet * 12 + inches).toDouble());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
