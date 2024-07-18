import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomLayout(
      title: 'Scans',
      body: Center(
        child: Consumer<UserPreferences>(
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
                    ],
                  )
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
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildUnitSetting(
    String title,
    String currentValue,
    void Function(String?) onChanged,
    List<String> options,
  ) {
    return CupertinoFormRow(
      prefix: Text(title),
      child: CupertinoSegmentedControl<String>(
        children: {for (var option in options) option: Text(option)},
        groupValue: currentValue,
        onValueChanged: onChanged,
      ),
    );
  }
}
