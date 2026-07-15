import 'dart:convert';
import 'package:cpr_instructor_doc/domain/atlas/atlas_csv_service.dart';
import 'package:cpr_instructor_doc/domain/atlas/atlas_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AtlasTemplateService {
  static const _key = 'atlas_custom_template_v1';
  Future<AtlasTemplate> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return AtlasTemplate.builtIn;
    try { return AtlasTemplate.fromJson((jsonDecode(raw) as Map).cast<String, Object?>()); } catch (_) { return AtlasTemplate.builtIn; }
  }
  Future<void> save(AtlasTemplate template) async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(template.toJson()));
  }
  Future<void> reset() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
  AtlasTemplate templateFromCsv({required String csv, required String name}) => AtlasTemplate(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        columns: const AtlasCsvService().decodeFirstRow(csv).map((h) => AtlasColumnMapping(header: h, field: _guess(h))).toList(growable: false),
      );
  AtlasField _guess(String header) {
    final h = header.trim().toLowerCase();
    if (h.contains('first') && h.contains('name')) return AtlasField.firstName;
    if (h.contains('last') && h.contains('name')) return AtlasField.lastName;
    if (h == 'name' || h.contains('full name')) return AtlasField.fullName;
    if (h.contains('email')) return AtlasField.email;
    if (h.contains('score') || h.contains('exam')) return AtlasField.writtenScore;
    if (h.contains('skill') && h.contains('date')) return AtlasField.skillsCheckOffDate;
    if (h.contains('issue') && h.contains('date')) return AtlasField.issueDate;
    if (h.contains('result') || h.contains('status')) return AtlasField.result;
    if (h.contains('course')) return AtlasField.course;
    if (h.contains('class') && h.contains('date')) return AtlasField.classDate;
    if (h.contains('additional') && h.contains('instructor')) return AtlasField.additionalInstructor;
    if (h.contains('instructor')) return AtlasField.instructor;
    if (h.contains('location')) return AtlasField.location;
    if (h.contains('training center')) return AtlasField.trainingCenter;
    if (h.contains('training site')) return AtlasField.trainingSite;
    return AtlasField.blank;
  }
}
