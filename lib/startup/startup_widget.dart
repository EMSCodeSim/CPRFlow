import 'package:cpr_instructor_doc/app/app_router.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/startup/startup_coordinator.dart';
import 'package:cpr_instructor_doc/startup/startup_state.dart';
import 'package:cpr_instructor_doc/ui/routes/recovery_screen.dart';
import 'package:cpr_instructor_doc/ui/routes/startup_screen.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Start immediately after first frame so the startup screen is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.coordinator.start();
    });
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

          final router = AppRouter.buildRouter(hasClassData: services.hasClassData);
          return AppScope(
            services: services,
            child: MaterialApp.router(
              title: 'CCF Timer',
              debugShowCheckedModeBanner: false,
              theme: widget.lightTheme,
              darkTheme: widget.darkTheme,
              themeMode: ThemeMode.system,
              routerConfig: router,
            ),
          );
        },
      ),
    );
  }
}
