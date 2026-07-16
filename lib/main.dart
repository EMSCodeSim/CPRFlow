import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'services/preferences_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await PreferencesService.create();
  final launchCount = await preferences.incrementLaunchCount();
  runApp(Stage5App(preferences: preferences, launchCount: launchCount));
}

class Stage5App extends StatefulWidget {
  const Stage5App({
    required this.preferences,
    required this.launchCount,
    super.key,
  });

  final PreferencesService preferences;
  final int launchCount;

  @override
  State<Stage5App> createState() => _Stage5AppState();
}

class _Stage5AppState extends State<Stage5App> {
  late final AppController controller;
  late final router = buildRouter(controller: controller);

  @override
  void initState() {
    super.initState();
    controller = AppController(
      preferences: widget.preferences,
      launchCount: widget.launchCount,
      onChanged: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CCF Timer Stage 5',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

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
