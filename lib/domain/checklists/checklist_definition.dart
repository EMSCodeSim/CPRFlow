import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_item_definition.dart';

class ChecklistDefinition {
  const ChecklistDefinition({required this.type, required this.title, required this.items});

  final ChecklistType type;
  final String title;
  final List<ChecklistItemDefinition> items;

  ChecklistItemDefinition itemById(String id) => items.firstWhere((e) => e.id == id);
}
