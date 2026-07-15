import 'dart:io';

import 'package:flutter/material.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.file, required this.title});
  final File file;
  final String title;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  double _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Rotate',
            onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: RotatedBox(
            quarterTurns: _quarterTurns.toInt(),
            child: Image.file(widget.file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
