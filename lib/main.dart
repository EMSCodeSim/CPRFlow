import 'dart:async';
import 'dart:ui';

import 'package:cpr_instructor_doc/normal_startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    startNormalApp();
  }, (Object error, StackTrace stack) {
    debugPrint('ZONED ERROR: $error');
    debugPrintStack(stackTrace: stack);
    runApp(_BootstrapFailureApp(error: error, stack: stack));
  });
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
    final copyText =
        'ERROR TYPE: $errorType\n\nERROR MESSAGE: $message\n\nSTACK:\n$stackText';

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
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: copyText),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
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
