import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService(this._preferences);

  static const _darkModeKey = 'stage5_dark_mode';
  static const _instructorNameKey = 'stage5_instructor_name';
  static const _launchCountKey = 'stage5_launch_count';

  final SharedPreferences _preferences;

  static Future<PreferencesService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesService(preferences);
  }

  bool get darkMode => _preferences.getBool(_darkModeKey) ?? false;
  String get instructorName =>
      _preferences.getString(_instructorNameKey) ?? '';
  int get launchCount => _preferences.getInt(_launchCountKey) ?? 0;

  Future<void> setDarkMode(bool value) =>
      _preferences.setBool(_darkModeKey, value);

  Future<void> setInstructorName(String value) =>
      _preferences.setString(_instructorNameKey, value);

  Future<int> incrementLaunchCount() async {
    final next = launchCount + 1;
    await _preferences.setInt(_launchCountKey, next);
    return next;
  }

  Future<void> clearStage5Data() async {
    await _preferences.remove(_darkModeKey);
    await _preferences.remove(_instructorNameKey);
    await _preferences.remove(_launchCountKey);
  }
}
