import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cpr_instructor_doc/normal_startup.dart' deferred as normal_startup;

/// Temporary flag to isolate startup/runtime failures.
///
/// When true, we intentionally avoid initializing *any* app services
/// (database, router, DI, PDF, documents, etc.) and render a minimal
/// Flutter widget tree to prove basic rendering works.
const bool startupDiagnosticMode = true;

void main() {
  runZonedGuarded(() async {
    // Keep binding init + runApp inside the same zone.
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}');
      debugPrintStack(stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PLATFORM ERROR: $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };

    ErrorWidget.builder = (FlutterErrorDetails details) => _DiagnosticErrorWidget(details: details);

    if (startupDiagnosticMode) {
      runApp(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Text('Startup Test', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      return;
    }

    // Only load the full app startup when diagnostic mode is disabled.
    await normal_startup.loadLibrary();
    normal_startup.startNormalApp();
  }, (error, stack) {
    debugPrint('ZONED ERROR: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class _DiagnosticErrorWidget extends StatelessWidget {
  const _DiagnosticErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final exception = details.exception;
    final stack = details.stack;
    final stackShort = _shortStack(stack);

    final errorType = exception.runtimeType.toString();
    final message = exception.toString();
    final copyText = 'ERROR TYPE: $errorType\n\nERROR MESSAGE: $message\n\nSTACK (short):\n$stackShort';

    return Material(
      color: const Color(0xFFFFFBFB),
      child: SafeArea(
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
                      'Widget build failed',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) ??
                          const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: copyText));
                      } catch (e) {
                        debugPrint('Failed to copy error to clipboard: $e');
                      }
                    },
                    icon: const Icon(Icons.copy, color: Colors.black87, size: 18),
                    label: const Text('Copy', style: TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Type: $errorType', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text('Message:', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(message, style: const TextStyle(fontFamily: 'monospace')),
                        const SizedBox(height: 12),
                        Text('Stack (short):', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        SelectableText(stackShort, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortStack(StackTrace? stackTrace) {
    if (stackTrace == null) return '(no stack trace)';
    final lines = stackTrace.toString().trim().split('\n');
    final take = lines.length > 18 ? 18 : lines.length;
    return lines.take(take).join('\n');
  }
}
