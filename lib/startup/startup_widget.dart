import 'package:cpr_instructor_doc/app/app_router.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_state.dart';
import 'package:cpr_instructor_doc/startup/startup_issue.dart';
import 'package:cpr_instructor_doc/ui/routes/recovery_screen.dart';
import 'package:cpr_instructor_doc/ui/routes/startup_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Root widget that:
/// 1) displays a startup screen immediately
/// 2) runs required startup initialization
/// 3) only constructs GoRouter after required init completes
class StartupWidget extends StatefulWidget {
  const StartupWidget({super.key, required this.coordinator, required this.lightTheme, required this.darkTheme});

  final StartupCoordinator coordinator;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  @override
  State<StartupWidget> createState() => _StartupWidgetState();
}

class _StartupWidgetState extends State<StartupWidget> {
  GoRouter? _router;
  AppServices? _routerServices;
  @override
  void initState() {
    super.initState();

    // Dreamflow runs the project as a web app. The class database uses the
    // browser sql.js/IndexedDB runtime, which can be blocked by the preview
    // environment before Drift is able to return a useful exception. Skip that
    // dependency entirely in web preview so the application always reaches its
    // home screen. Android and iOS continue through the normal database startup.
    if (kIsWeb) {
      widget.coordinator.openWithoutClassData();
      return;
    }

    // Start immediately after first frame so the startup screen is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.coordinator.start();
    });
  }


  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.coordinator,
      child: Consumer<StartupCoordinator>(
        builder: (context, coordinator, _) {
          final state = coordinator.state;
          if (state.phase == StartupPhase.initializing || state.phase == StartupPhase.idle) {
            return MaterialApp(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              home: const StartupScreen(),
            );
          }

          if (state.phase == StartupPhase.recovery) {
            return MaterialApp(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              home: RecoveryScreen(
                issues: state.issues,
                onRetry: coordinator.retry,
                onOpenWithoutClassData: coordinator.openWithoutClassData,
              ),
            );
          }

          final services = coordinator.services;
          if (services == null) {
            return MaterialApp(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              home: RecoveryScreen(
                issues: const [],
                onRetry: coordinator.retry,
                onOpenWithoutClassData: coordinator.openWithoutClassData,
              ),
            );
          }

          try {
            if (!identical(_routerServices, services) || _router == null) {
              _router?.dispose();
              _routerServices = services;
              _router = AppRouter.buildRouter(hasClassData: services.hasClassData);
            }
          } catch (error, stackTrace) {
            debugPrint('Router construction failed: $error\n$stackTrace');
            return MaterialApp(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              home: RecoveryScreen(
                issues: [
                  StartupIssue(
                    kind: StartupIssueKind.databaseHealthCheckFailed,
                    message: 'Navigation could not be initialized: $error',
                    stackTrace: stackTrace,
                  ),
                ],
                onRetry: coordinator.retry,
                onOpenWithoutClassData: coordinator.openWithoutClassData,
              ),
            );
          }
          return AppScope(
            services: services,
            child: MaterialApp.router(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              routerConfig: _router!,
            ),
          );
        },
      ),
    );
  }
}
