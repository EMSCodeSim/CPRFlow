import 'dart:typed_data';

import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/documents/class_package_service.dart';
import 'package:cpr_instructor_doc/ui/documents/document_preview_request.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class ClassDocumentsScreen extends StatefulWidget {
  const ClassDocumentsScreen.live({super.key, required this.classId})
      : snapshotId = null,
        readOnly = false,
        studentId = null;

  const ClassDocumentsScreen.snapshot({super.key, required this.snapshotId})
      : classId = null,
        readOnly = true,
        studentId = null;

  const ClassDocumentsScreen.student({super.key, required this.classId, required this.studentId, required this.readOnly}) : snapshotId = null;

  final String? classId;
  final String? snapshotId;
  final bool readOnly;
  final String? studentId;

  @override
  State<ClassDocumentsScreen> createState() => _ClassDocumentsScreenState();
}

class _ClassDocumentsScreenState extends State<ClassDocumentsScreen> {
  String _search = '';
  bool _busy = false;
  Future<String?>? _classIdFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _classIdFuture ??= _resolveClassId();
  }

  Future<String?> _resolveClassId() async {
    final id = widget.classId;
    if (id != null) return id;
    final snapshotId = widget.snapshotId;
    if (snapshotId == null) return null;
    final db = AppScope.of(context).database;
    if (db == null) return null;
    final snap = await (db.select(db.finalClassSnapshots)..where((t) => t.id.equals(snapshotId))).getSingleOrNull();
    return snap?.classId;
  }

  Future<void> _addDocumentBottomSheet(String classId) async {
    if (widget.readOnly) return;
    final type = await showModalBottomSheet<DocumentType>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AddDocumentSheet(studentId: widget.studentId),
    );
    if (type == null) return;

    // Source selection: PDF/TXT via FilePicker; images via ImagePicker.
    if (!mounted) return;
    final picker = ImagePicker();

    try {
      setState(() => _busy = true);
      Uint8List bytes;
      String filename;

      if (type == DocumentType.studentPhoto) {
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (context) => const _ImageSourceSheet(),
        );
        if (source == null) return;
        final x = await picker.pickImage(source: source, imageQuality: 92);
        if (x == null) return;
        bytes = await x.readAsBytes();
        filename = x.name;
      } else {
        final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'heic', 'txt']);
        if (result == null || result.files.isEmpty) return;
        final f = result.files.single;
        if (f.bytes == null) throw StateError('Selected file could not be read');
        bytes = f.bytes!;
        filename = f.name;
      }

      if (!mounted) return;
      final services = AppScope.of(context);
      final storage = services.documentStorageService;
      if (storage == null) throw StateError('Document storage disabled');
      final displayName = filename;
      await storage.importBytes(
        classId: classId,
        studentId: widget.studentId,
        documentType: type,
        displayName: displayName,
        originalFilename: filename,
        bytes: bytes,
      );
    } catch (e, st) {
      debugPrint('Add document failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add document: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareClassPackage(String classId) async {
    try {
      if (!mounted) return;
      setState(() => _busy = true);
      final services = AppScope.of(context);
      final db = services.database;
      final report = services.classReportService;
      final storage = services.documentStorageService;
      if (db == null || report == null || storage == null) throw StateError('Services not available');
      final package = ClassPackageService(db: db, reportService: report, documentStorageService: storage);
      final result = await package.exportLiveClassPackage(classId: classId);
      await Share.shareXFiles([XFile(result.file.path)], text: 'Class package: ${result.manifest.className}');
    } catch (e, st) {
      debugPrint('Export class package failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importClassPackage() async {
    if (widget.readOnly) return;
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['zip']);
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) throw StateError('Could not read ZIP');

      if (!mounted) return;
      setState(() => _busy = true);
      final services = AppScope.of(context);
      final db = services.database;
      final report = services.classReportService;
      final storage = services.documentStorageService;
      if (db == null || report == null || storage == null) throw StateError('Services not available');
      final package = ClassPackageService(db: db, reportService: report, documentStorageService: storage);
      final newClassId = await package.importClassPackage(zipBytes: bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported package as a new working copy class.')));
      context.go('/class/edit?id=$newClassId');
    } catch (e, st) {
      debugPrint('Import class package failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final repo = services.documentRepository;

    return FutureBuilder<String?>(
      future: _classIdFuture,
      builder: (context, snap) {
        final classId = snap.data;
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (classId == null || classId.isEmpty) {
          return const SafeErrorScreen(title: 'Missing class', message: 'No class ID available for documents.');
        }

        final stream = widget.studentId != null
            ? repo.watchForStudent(studentId: widget.studentId!)
            : repo.watchForClass(classId: classId);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.studentId != null ? 'Student Documents' : 'Class Documents'),
            actions: [
              if (!widget.readOnly) IconButton(tooltip: 'Import package', onPressed: _busy ? null : _importClassPackage, icon: const Icon(Icons.archive)),
              if (widget.studentId == null && !widget.readOnly)
                IconButton(tooltip: 'Export package', onPressed: _busy ? null : () => _shareClassPackage(classId), icon: const Icon(Icons.upload)),
            ],
          ),
          floatingActionButton: widget.readOnly
              ? null
              : FloatingActionButton.extended(
                  onPressed: _busy ? null : () => _addDocumentBottomSheet(classId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search filename or notes'),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ClassDocument>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Documents could not be loaded.'),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: () => setState(() {}), child: const Text('Retry')),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = (snapshot.data ?? const []).where((d) {
                      if (_search.trim().isEmpty) return true;
                      final q = _search.trim().toLowerCase();
                      return d.displayName.toLowerCase().contains(q) || d.originalFilename.toLowerCase().contains(q) || (d.notes ?? '').toLowerCase().contains(q);
                    }).toList(growable: false);

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(widget.readOnly ? 'No documents.' : 'No documents yet. Tap Add to attach PDFs or images.', textAlign: TextAlign.center),
                      );
                    }

                    final grouped = <DocumentType, List<ClassDocument>>{};
                    for (final d in docs) {
                      grouped.putIfAbsent(d.documentType, () => []).add(d);
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: grouped.entries.map((e) => _DocumentTypeSection(type: e.key, docs: e.value, readOnly: widget.readOnly)).toList(growable: false),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentTypeSection extends StatelessWidget {
  const _DocumentTypeSection({required this.type, required this.docs, required this.readOnly});
  final DocumentType type;
  final List<ClassDocument> docs;
  final bool readOnly;

  String get _title => switch (type) {
        DocumentType.writtenTest => 'Written Tests',
        DocumentType.classRoster => 'Class Roster',
        DocumentType.atlasRoster => 'Atlas Roster',
        DocumentType.attendance => 'Attendance',
        DocumentType.studentSkillSheet => 'Skill Sheets',
        DocumentType.studentEvaluation => 'Evaluations',
        DocumentType.studentPhoto => 'Photos',
        DocumentType.miscellaneous => 'Miscellaneous',
      };

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(_title),
      subtitle: Text('${docs.length} document${docs.length == 1 ? '' : 's'}'),
      children: docs.map((d) => _DocumentTile(doc: d, readOnly: readOnly)).toList(growable: false),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc, required this.readOnly});
  final ClassDocument doc;
  final bool readOnly;

  IconData get _icon {
    final m = doc.mimeType.toLowerCase();
    if (m == 'application/pdf') return Icons.picture_as_pdf;
    if (m.startsWith('image/')) return Icons.image;
    if (m.startsWith('text/')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Future<void> _open(BuildContext context) async {
    await context.push('/documents/preview', extra: DocumentPreviewRequest(document: doc));
  }

  Future<void> _share(BuildContext context) async {
    final storage = AppScope.of(context).documentStorageService;
    if (storage == null) return;
    try {
      final file = await storage.openFile(doc);
      await Share.shareXFiles([XFile(file.path)], text: doc.displayName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _edit(BuildContext context) async {
    if (readOnly) return;
    final result = await showDialog<_DocumentEditResult>(
      context: context,
      builder: (context) => _DocumentEditDialog(document: doc),
    );
    if (result == null || !context.mounted) return;
    final storage = AppScope.of(context).documentStorageService;
    if (storage == null) return;
    try {
      await storage.updateDetails(
        doc: doc,
        displayName: result.displayName,
        documentType: result.documentType,
        studentId: doc.studentId,
        notes: result.notes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (readOnly) return;
    final services = AppScope.of(context);
    final storage = services.documentStorageService;
    if (storage == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('This will remove "${doc.displayName}" from this class.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await storage.delete(doc: doc);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon),
      title: Text(doc.displayName),
      subtitle: Text(
        [doc.originalFilename, if (doc.notes != null && doc.notes!.trim().isNotEmpty) doc.notes!.trim()].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'open') _open(context);
          if (v == 'share') _share(context);
          if (v == 'edit') _edit(context);
          if (v == 'delete') _delete(context);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'open', child: Text('Preview')),
          const PopupMenuItem(value: 'share', child: Text('Share')),
          if (!readOnly) const PopupMenuItem(value: 'edit', child: Text('Rename / Details')),
          if (!readOnly) const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () => _open(context),
    );
  }
}

class _DocumentEditResult {
  const _DocumentEditResult({required this.displayName, required this.documentType, required this.notes});
  final String displayName;
  final DocumentType documentType;
  final String? notes;
}

class _DocumentEditDialog extends StatefulWidget {
  const _DocumentEditDialog({required this.document});
  final ClassDocument document;

  @override
  State<_DocumentEditDialog> createState() => _DocumentEditDialogState();
}

class _DocumentEditDialogState extends State<_DocumentEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late DocumentType _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.document.displayName);
    _notes = TextEditingController(text: widget.document.notes ?? '');
    _type = widget.document.documentType;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Category'),
              items: DocumentType.values
                  .map((type) => DropdownMenuItem(value: type, child: Text(_documentTypeLabel(type))))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _DocumentEditResult(
              displayName: _name.text.trim(),
              documentType: _type,
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _documentTypeLabel(DocumentType type) => switch (type) {
      DocumentType.writtenTest => 'Written Test',
      DocumentType.classRoster => 'Class Roster',
      DocumentType.atlasRoster => 'Atlas Roster',
      DocumentType.attendance => 'Attendance',
      DocumentType.studentSkillSheet => 'Student Skill Sheet',
      DocumentType.studentEvaluation => 'Student Evaluation',
      DocumentType.studentPhoto => 'Student Photo',
      DocumentType.miscellaneous => 'Miscellaneous',
    };

class _AddDocumentSheet extends StatelessWidget {
  const _AddDocumentSheet({required this.studentId});
  final String? studentId;

  @override
  Widget build(BuildContext context) {
    final options = <(DocumentType, String, IconData)>[
      (DocumentType.writtenTest, 'Written test', Icons.assignment_turned_in),
      (DocumentType.classRoster, 'Class roster', Icons.people),
      (DocumentType.attendance, 'Attendance', Icons.how_to_reg),
      (DocumentType.studentSkillSheet, 'Student skill sheet', Icons.checklist),
      (DocumentType.studentEvaluation, 'Student evaluation', Icons.rate_review),
      (DocumentType.studentPhoto, 'Photo (camera/gallery)', Icons.photo_camera),
      (DocumentType.miscellaneous, 'Miscellaneous', Icons.folder),
    ];

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(studentId == null ? 'Add class document' : 'Add student document', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...options.map(
            (o) => ListTile(
              leading: Icon(o.$3),
              title: Text(o.$2),
              onTap: () => Navigator.of(context).pop<DocumentType>(o.$1),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.of(context).pop(ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.of(context).pop(ImageSource.camera)),
        ],
      ),
    );
  }
}
