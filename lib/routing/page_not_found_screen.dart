import 'package:flutter/material.dart';

class PageNotFoundScreen extends StatelessWidget {
  const PageNotFoundScreen({required this.location, required this.onGoHome, super.key});

  final String location;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48),
              const SizedBox(height: 12),
              const Text('Page not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onGoHome,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
