import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/adult_bls_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_definition.dart';
import 'package:cpr_instructor_doc/domain/checklists/infant_child_bls_definition.dart';

class ChecklistRegistry {
  static final ChecklistDefinition _adult = AdultBlsDefinition.build();
  static final ChecklistDefinition _infantChild = InfantChildBlsDefinition.build();

  static ChecklistDefinition definitionFor(ChecklistType type) {
    switch (type) {
      case ChecklistType.adult:
        return _adult;
      case ChecklistType.infantChild:
        return _infantChild;
    }
  }
}
