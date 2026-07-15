import 'dart:io';

import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/ui/documents/document_preview_request.dart';
import 'package:cpr_instructor_doc/ui/documents/image_viewer_screen.dart';
import 'package:cpr_instructor_doc/ui/documents/pdf_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({super.key, required this.request});
  final DocumentPreviewRequest request;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  File? _file;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = AppScope.of(context).documentStorageService;
    if (storage == null) {
      setState(() {
        _loading = false;
        _error = StateError('Document storage disabled');
      });
      return;
    }
    try {
      final f = await storage.openFile(widget.request.document);
      setState(() {
        _file = f;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load document: $e\n$st');
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _share() async {
    final f = _file;
    if (f == null) return;
    await Share.shareXFiles([XFile(f.path)], text: widget.request.document.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.request.document;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.displayName),
        actions: [
          IconButton(onPressed: _file == null ? null : _share, icon: const Icon(Icons.share)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Unable to open file: $_error'))
              : _buildViewer(doc: doc, file: _file!),
    );
  }

  Widget _buildViewer({required dynamic doc, required File file}) {
    final mime = (doc.mimeType as String).toLowerCase();
    if (mime == 'application/pdf') return PdfViewerScreen(file: file, title: doc.displayName);
    if (mime.startsWith('image/')) return ImageViewerScreen(file: file, title: doc.displayName);
    if (mime.startsWith('text/')) {
      return FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(snap.data!));
        },
      );
    }
    return Center(child: Text('Preview not supported for $mime'));
  }
}
