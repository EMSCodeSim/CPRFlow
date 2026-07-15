import 'dart:io';

import 'package:cpr_instructor_doc/domain/atlas/atlas_template.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AtlasTemplateSettingsScreen extends StatefulWidget {
  const AtlasTemplateSettingsScreen({super.key});

  @override
  State<AtlasTemplateSettingsScreen> createState() => _AtlasTemplateSettingsScreenState();
}

class _AtlasTemplateSettingsScreenState extends State<AtlasTemplateSettingsScreen> {
  final _service = AtlasTemplateService();
  AtlasTemplate? _template;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final template = await _service.load();
    if (mounted) setState(() { _template = template; _loading = false; });
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv']);
    final path = result?.files.single.path;
    if (path == null) return;
    final csv = await File(path).readAsString();
    final imported = _service.templateFromCsv(csv: csv, name: result!.files.single.name);
    await _service.save(imported);
    if (mounted) setState(() => _template = imported);
  }

  Future<void> _updateColumn(int index, AtlasField field) async {
    final current = _template!;
    final columns = [...current.columns];
    columns[index] = AtlasColumnMapping(header: columns[index].header, field: field, fixedValue: columns[index].fixedValue);
    final updated = AtlasTemplate(id: current.id, name: current.name, columns: columns, dateFormat: current.dateFormat, isBuiltIn: false);
    await _service.save(updated);
    if (mounted) setState(() => _template = updated);
  }

  Future<void> _reset() async {
    await _service.reset();
    if (mounted) setState(() => _template = AtlasTemplate.builtIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atlas Template Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_template!.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Date format: ${_template!.dateFormat}'),
                const SizedBox(height: 16),
                for (var i = 0; i < _template!.columns.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: Text(_template!.columns[i].header)),
                        const SizedBox(width: 12),
                        DropdownButton<AtlasField>(
                          value: _template!.columns[i].field,
                          onChanged: (value) { if (value != null) _updateColumn(i, value); },
                          items: AtlasField.values.map((field) => DropdownMenuItem(value: field, child: Text(field.name))).toList(),
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file), label: const Text('Import CSV Template')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _reset, child: const Text('Reset to Default')),
              ],
            ),
    );
  }
}
