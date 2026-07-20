import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ccf_timer_low_risk_test/app/app_state.dart';
import 'package:ccf_timer_low_risk_test/app/app_state_scope.dart';
import 'package:ccf_timer_low_risk_test/app/restoration_prefs_controller.dart';
import 'package:ccf_timer_low_risk_test/services/preferences_service.dart';
import 'package:ccf_timer_low_risk_test/screens/archive_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/archived_class_detail_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/ccf_evaluation_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/checklist_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/class_selection_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/home_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/image_viewer_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/new_class_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/reports_center_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/settings_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/student_detail_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/student_form_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/test_score_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/today_class_screen.dart';
import 'package:ccf_timer_low_risk_test/screens/asset_test_screen.dart';
import 'package:ccf_timer_low_risk_test/theme.dart';
import 'package:ccf_timer_low_risk_test/routing/page_not_found_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = await _bootWithTimeout();
  runApp(LowRiskTestApp(
    initialDarkMode: boot.darkMode,
    initialInstructorName: boot.instructorName,
    initialLaunchCount: boot.launchCount,
    showPrefsLoadError: boot.showPrefsLoadError,
    preferencesService: boot.preferencesService,
  ));
}

class _BootResult {
  const _BootResult({
    required this.darkMode,
    required this.instructorName,
    required this.launchCount,
    required this.showPrefsLoadError,
    required this.preferencesService,
  });

  final bool darkMode;
  final String instructorName;
  final int launchCount;
  final bool showPrefsLoadError;
  final PreferencesService? preferencesService;
}

Future<_BootResult> _bootWithTimeout() async {
  try {
    final service = await PreferencesService.create().timeout(const Duration(seconds: 4));
    final nextLaunchCount = service.launchCount + 1;
    final launchCountSaved = await service.setLaunchCount(nextLaunchCount);
    return _BootResult(
      darkMode: service.darkMode,
      instructorName: service.instructorName,
      launchCount: nextLaunchCount,
      showPrefsLoadError: !launchCountSaved,
      preferencesService: service,
    );
  } on TimeoutException catch (e) {
    debugPrint('SharedPreferences init timed out: $e');
  } catch (e) {
    debugPrint('SharedPreferences init failed: $e');
  }

  return const _BootResult(
    darkMode: false,
    instructorName: '',
    launchCount: 0,
    showPrefsLoadError: true,
    preferencesService: null,
  );
}

class LowRiskTestApp extends StatefulWidget {
  const LowRiskTestApp({
    required this.initialDarkMode,
    required this.initialInstructorName,
    required this.initialLaunchCount,
    required this.showPrefsLoadError,
    required this.preferencesService,
    super.key,
  });

  final bool initialDarkMode;
  final String initialInstructorName;
  final int initialLaunchCount;
  final bool showPrefsLoadError;
  final PreferencesService? preferencesService;

  @override
  State<LowRiskTestApp> createState() => _LowRiskTestAppState();
}

class _LowRiskTestAppState extends State<LowRiskTestApp> {
  late final RestorationPrefsController controller;
  late final AppState appState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    controller = RestorationPrefsController(
      preferencesService: widget.preferencesService,
      darkMode: widget.initialDarkMode,
      instructorName: widget.initialInstructorName,
      launchCount: widget.initialLaunchCount,
      showPrefsLoadError: widget.showPrefsLoadError,
    );

    appState = AppState();

    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', name: 'home', builder: (context, state) => HomeScreen(prefsController: controller)),
        GoRoute(path: '/classes', name: 'classes', builder: (context, state) => const ClassSelectionScreen()),
        GoRoute(
          path: '/new-class',
          name: 'new-class',
          builder: (context, state) => NewClassScreen(defaultPrimaryInstructorName: controller.instructorName),
        ),
        GoRoute(path: '/today-class', name: 'today-class', builder: (context, state) => const TodayClassScreen()),
        GoRoute(path: '/students/new', name: 'student-new', builder: (context, state) => const StudentFormScreen(studentId: 'new')),
        GoRoute(
          path: '/students/:studentId',
          name: 'student-detail',
          builder: (context, state) => StudentDetailScreen(studentId: state.pathParameters['studentId'] ?? ''),
        ),
        GoRoute(
          path: '/students/:studentId/edit',
          name: 'student-edit',
          builder: (context, state) => StudentFormScreen(studentId: state.pathParameters['studentId'] ?? ''),
        ),
        GoRoute(
          path: '/students/:studentId/adult-checklist',
          name: 'adult-checklist',
          builder: (context, state) => ChecklistScreen(studentId: state.pathParameters['studentId'] ?? '', kind: ChecklistKind.adult),
        ),
        GoRoute(
          path: '/students/:studentId/infant-checklist',
          name: 'infant-checklist',
          builder: (context, state) => ChecklistScreen(studentId: state.pathParameters['studentId'] ?? '', kind: ChecklistKind.infant),
        ),
        GoRoute(
          path: '/students/:studentId/ccf',
          name: 'student-ccf',
          builder: (context, state) => CcfEvaluationScreen(studentId: state.pathParameters['studentId'] ?? ''),
        ),
        GoRoute(
          path: '/students/:studentId/test-score',
          name: 'student-test-score',
          builder: (context, state) => TestScoreScreen(studentId: state.pathParameters['studentId'] ?? ''),
        ),
        GoRoute(path: '/timer', name: 'timer', builder: (context, state) => const LocalTimerScreen()),
        GoRoute(path: '/reports', name: 'reports', builder: (context, state) => const ReportsCenterScreen()),
        GoRoute(path: '/archive', name: 'archive', builder: (context, state) => const ArchiveScreen()),
        GoRoute(
          path: '/archive/:archivedId',
          name: 'archived-detail',
          builder: (context, state) => ArchivedClassDetailScreen(archivedId: state.pathParameters['archivedId'] ?? ''),
        ),
        GoRoute(path: '/settings', name: 'settings', builder: (context, state) => SettingsScreen(controller: controller)),
        GoRoute(path: '/asset-test', name: 'asset-test', builder: (context, state) => const AssetTestScreen()),
        GoRoute(
          path: '/image/:imageId',
          name: 'image-viewer',
          builder: (context, state) => ImageViewerScreen(imageId: state.pathParameters['imageId'] ?? ''),
        ),
      ],
      errorBuilder: (context, state) => PageNotFoundScreen(
        location: state.uri.toString(),
        onGoHome: () => context.go('/'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: appState,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'CCF Timer',
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}

class LocalTimerScreen extends StatefulWidget {
  const LocalTimerScreen({super.key});

  @override
  State<LocalTimerScreen> createState() => _LocalTimerScreenState();
}

class _LocalTimerScreenState extends State<LocalTimerScreen> {
  Timer? timer;
  int seconds = 0;
  bool running = false;

  void toggle() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes:$remaining', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 24),
            FilledButton(onPressed: toggle, child: Text(running ? 'Pause' : 'Start')),
            TextButton(
              onPressed: () {
                timer?.cancel();
                setState(() {
                  running = false;
                  seconds = 0;
                });
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
