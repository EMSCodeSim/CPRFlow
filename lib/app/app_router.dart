import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens.dart';

GoRouter buildRouter({required AppController controller}) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => HomeScreen(controller: controller),
      ),
      GoRoute(
        path: '/class',
        name: 'class',
        builder: (context, state) => const LocalFormScreen(),
      ),
      GoRoute(
        path: '/timer',
        name: 'timer',
        builder: (context, state) => const LocalTimerScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => SettingsScreen(controller: controller),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Route error')),
      body: Center(child: Text(state.error.toString())),
    ),
  );
}
