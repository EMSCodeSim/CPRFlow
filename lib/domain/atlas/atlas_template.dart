enum AtlasField { firstName, lastName, fullName, email, writtenScore, skillsCheckOffDate, issueDate, result, course, classDate, instructor, additionalInstructor, location, trainingCenter, trainingSite, blank, fixedValue }

class AtlasColumnMapping {
  const AtlasColumnMapping({required this.header, required this.field, this.fixedValue});
  final String header;
  final AtlasField field;
  final String? fixedValue;
  Map<String, Object?> toJson() => {'header': header, 'field': field.name, 'fixedValue': fixedValue};
  factory AtlasColumnMapping.fromJson(Map<String, Object?> json) => AtlasColumnMapping(
        header: json['header'] as String,
        field: AtlasField.values.byName(json['field'] as String),
        fixedValue: json['fixedValue'] as String?,
      );
}

class AtlasTemplate {
  const AtlasTemplate({required this.id, required this.name, required this.columns, this.dateFormat = 'MM/dd/yyyy', this.isBuiltIn = false});
  final String id;
  final String name;
  final List<AtlasColumnMapping> columns;
  final String dateFormat;
  final bool isBuiltIn;

  static const builtIn = AtlasTemplate(
    id: 'default_atlas',
    name: 'Default Atlas Roster',
    isBuiltIn: true,
    columns: [
      AtlasColumnMapping(header: 'First Name', field: AtlasField.firstName),
      AtlasColumnMapping(header: 'Last Name', field: AtlasField.lastName),
      AtlasColumnMapping(header: 'Email', field: AtlasField.email),
      AtlasColumnMapping(header: 'Final Exam Score', field: AtlasField.writtenScore),
      AtlasColumnMapping(header: 'Skills Check-Off Date', field: AtlasField.skillsCheckOffDate),
      AtlasColumnMapping(header: 'Issue Date', field: AtlasField.issueDate),
      AtlasColumnMapping(header: 'Result', field: AtlasField.result),
    ],
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'dateFormat': dateFormat, 'isBuiltIn': isBuiltIn, 'columns': columns.map((e) => e.toJson()).toList()};
  factory AtlasTemplate.fromJson(Map<String, Object?> json) => AtlasTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        dateFormat: (json['dateFormat'] as String?) ?? 'MM/dd/yyyy',
        isBuiltIn: (json['isBuiltIn'] as bool?) ?? false,
        columns: (json['columns'] as List).cast<Map>().map((e) => AtlasColumnMapping.fromJson(e.cast<String, Object?>())).toList(growable: false),
      );
}
