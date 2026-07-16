import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ULTRA-MINIMAL BOOT (temporary)
///
/// This entrypoint intentionally bypasses everything app-specific (go_router,
/// database init, coordinators, custom themes, etc.) to guarantee that Preview
/// renders a basic screen.
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
      debugPrintStack(stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('PLATFORM ERROR: $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };

    ErrorWidget.builder = (FlutterErrorDetails details) =>
        _DiagnosticErrorWidget(details: details);

    runApp(const _GuaranteedBootApp());
  }, (Object error, StackTrace stack) {
    debugPrint('ZONED ERROR: $error');
    debugPrintStack(stackTrace: stack);
    runApp(_BootstrapFailureApp(error: error, stack: stack));
  });
}

class _GuaranteedBootApp extends StatelessWidget {
  const _GuaranteedBootApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Boot Test',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const _GuaranteedBootScreen(),
      );
}

class _GuaranteedBootScreen extends StatelessWidget {
  const _GuaranteedBootScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    'App is running',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This is a guaranteed minimal startup screen.\n'
                    'If Preview is still blank, the issue is outside Flutter code\n'
                    '(Preview target / browser debug attachment).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: _ErrorDetails(
            title: 'App startup failed',
            errorType: error.runtimeType.toString(),
            message: error.toString(),
            stack: stack,
          ),
        ),
      );
}

class _DiagnosticErrorWidget extends StatelessWidget {
  const _DiagnosticErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) => Material(
        child: _ErrorDetails(
          title: 'Screen failed to load',
          errorType: details.exception.runtimeType.toString(),
          message: details.exceptionAsString(),
          stack: details.stack,
        ),
      );
}

class _ErrorDetails extends StatelessWidget {
  const _ErrorDetails({
    required this.title,
    required this.errorType,
    required this.message,
    required this.stack,
  });

  final String title;
  final String errorType;
  final String message;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    final stackText = _shortStack(stack);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Type: $errorType'),
            const SizedBox(height: 8),
            const Text(
              'Message:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  '$message\n\nStack:\n$stackText',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortStack(StackTrace? stackTrace) {
    if (stackTrace == null) return '(no stack trace)';
    final lines = stackTrace.toString().trim().split('\n');
    return lines.take(24).join('\n');
  }
}
