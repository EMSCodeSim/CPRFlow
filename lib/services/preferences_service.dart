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

  Future<bool> setDarkMode(bool value) => _preferences.setBool(_darkModeKey, value);

  Future<bool> setInstructorName(String value) => _preferences.setString(_instructorNameKey, value);

  /// Saves the raw launch count value.
  ///
  /// Returns `true` if the value was persisted successfully.
  Future<bool> setLaunchCount(int value) => _preferences.setInt(_launchCountKey, value);

  Future<int> incrementLaunchCount() async {
    final next = launchCount + 1;
    await setLaunchCount(next);
    return next;
  }

  Future<bool> clearStage5Data() async {
    final a = await _preferences.remove(_darkModeKey);
    final b = await _preferences.remove(_instructorNameKey);
    final c = await _preferences.remove(_launchCountKey);
    return a && b && c;
  }
}
