import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: UserPreferences(),
      child: CustomLayout(
        title: 'Profile and Settings',
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
                    _buildSettingsGroup(
                      'Personal Information',
                      [
                        _buildHeightSetting(userPreferences),
                        _buildWeightSetting(userPreferences),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
    final Map<String, Widget> segmentTextWidgets = <String, Widget>{
      for (var option in options)
        option: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(option),
        ),
    };

    return CupertinoFormRow(
      prefix: Text(title),
      child: CupertinoSegmentedControl<String>(
        groupValue: currentValue,
        onValueChanged: onChanged,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
        children: segmentTextWidgets,
      ),
    );
  }

  Widget _buildHeightSetting(UserPreferences userPreferences) {
    return CupertinoFormRow(
      prefix: const Text('Enter your height:'),
      child: SizedBox(
        width: 100,
        child: CupertinoTextField(
          placeholder: 'Height',
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final height = double.tryParse(value);
            if (height != null) {
              userPreferences.setHeight(height);
            }
          },
          suffix: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Text(userPreferences.heightUnit),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightSetting(UserPreferences userPreferences) {
    return CupertinoFormRow(
      prefix: const Text('Enter your weight:'),
      child: SizedBox(
        width: 100,
        child: CupertinoTextField(
          placeholder: 'Weight',
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final height = double.tryParse(value);
            if (height != null) {
              userPreferences.setWeight(height);
            }
          },
          suffix: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Text(userPreferences.weightUnit),
          ),
        ),
      ),
    );
  }
}
