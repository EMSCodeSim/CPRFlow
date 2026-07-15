class ChecklistItemDefinition {
  const ChecklistItemDefinition({
    required this.id,
    required this.title,
    required this.instructorPrompt,
    required this.imageAssetPath,
    required this.required,
    required this.order,
    required this.section,
    this.optionalTeachingNote,
  });

  final String id;
  final String title;
  final String instructorPrompt;
  final String? imageAssetPath;
  final bool required;
  final int order;
  final String section;
  final String? optionalTeachingNote;
}
