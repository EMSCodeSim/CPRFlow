import 'package:flutter/foundation.dart';

import 'package:ccf_timer_low_risk_test/services/preferences_service.dart';

enum PrefSaveResult { success, unavailable, failed }

class RestorationPrefsController extends ChangeNotifier {
  RestorationPrefsController({
    required PreferencesService? preferencesService,
    required bool darkMode,
    required String instructorName,
    required int launchCount,
    required bool showPrefsLoadError,
  })  : _preferencesService = preferencesService,
        _darkMode = darkMode,
        _instructorName = instructorName,
        _launchCount = launchCount,
        _showPrefsLoadError = showPrefsLoadError;

  PreferencesService? _preferencesService;
  bool _darkMode;
  String _instructorName;
  int _launchCount;
  bool _showPrefsLoadError;

  bool get darkMode => _darkMode;
  String get instructorName => _instructorName;
  int get launchCount => _launchCount;
  bool get showPrefsLoadError => _showPrefsLoadError;

  Future<PrefSaveResult> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    try {
      final svc = _preferencesService;
      if (svc == null) return PrefSaveResult.unavailable;
      final ok = await svc.setDarkMode(value);
      if (!ok) {
        _showPrefsLoadError = true;
        notifyListeners();
        return PrefSaveResult.failed;
      }
      return PrefSaveResult.success;
    } catch (e) {
      debugPrint('Failed to persist dark mode: $e');
      _showPrefsLoadError = true;
      notifyListeners();
      return PrefSaveResult.failed;
    }
  }

  Future<PrefSaveResult> setInstructorName(String value) async {
    _instructorName = value;
    notifyListeners();
    try {
      final svc = _preferencesService;
      if (svc == null) return PrefSaveResult.unavailable;
      final ok = await svc.setInstructorName(value);
      if (!ok) {
        _showPrefsLoadError = true;
        notifyListeners();
        return PrefSaveResult.failed;
      }
      return PrefSaveResult.success;
    } catch (e) {
      debugPrint('Failed to persist instructor name: $e');
      _showPrefsLoadError = true;
      notifyListeners();
      return PrefSaveResult.failed;
    }
  }

  Future<PrefSaveResult> clearStage5Data() async {
    try {
      final svc = _preferencesService;
      if (svc == null) {
        _darkMode = false;
        _instructorName = '';
        _launchCount = 0;
        notifyListeners();
        return PrefSaveResult.unavailable;
      }

      final ok = await svc.clearStage5Data();
      _darkMode = false;
      _instructorName = '';
      _launchCount = 0;
      if (ok) _showPrefsLoadError = false;
      notifyListeners();
      return ok ? PrefSaveResult.success : PrefSaveResult.failed;
    } catch (e) {
      debugPrint('Failed to clear saved preferences: $e');
      _showPrefsLoadError = true;
      notifyListeners();
      return PrefSaveResult.failed;
    }
  }
}
