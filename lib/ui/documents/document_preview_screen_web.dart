import 'package:cpr_instructor_doc/ui/documents/document_preview_request.dart';
import 'package:flutter/material.dart';

class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({super.key, required this.request});
  final DocumentPreviewRequest request;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(request.document.displayName)),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Document preview is available in the Android and iOS app. The web preview remains available for the rest of the class workflow.'),
      ),
    ),
  );
}
