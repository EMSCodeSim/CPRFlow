import 'package:flutter/foundation.dart';

import '../services/preferences_service.dart';

class AppController {
  AppController({
    required this.preferences,
    required this.launchCount,
    required this.onChanged,
  })  : darkMode = preferences.darkMode,
        instructorName = preferences.instructorName;

  final PreferencesService preferences;
  final VoidCallback onChanged;

  int launchCount;
  bool darkMode;
  String instructorName;

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    onChanged();
    await preferences.setDarkMode(value);
  }

  Future<void> setInstructorName(String value) async {
    instructorName = value;
    onChanged();
    await preferences.setInstructorName(value);
  }

  Future<void> clearSavedData() async {
    await preferences.clearStage5Data();
    darkMode = false;
    instructorName = '';
    launchCount = 0;
    onChanged();
  }
}
