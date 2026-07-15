class ScoreEditState {
  const ScoreEditState({
    required this.studentId,
    required this.originalScore,
    required this.draftScore,
    required this.originalFinalized,
    required this.draftFinalized,
    required this.rawDraft,
    required this.validationError,
    required this.isDirty,
    required this.isSaving,
    required this.saveError,
  });

  final String studentId;
  final int? originalScore;
  final int? draftScore;
  final bool originalFinalized;
  final bool draftFinalized;

  /// Raw text as typed (kept so the UI can reflect invalid partial input).
  final String rawDraft;

  final String? validationError;
  final bool isDirty;
  final bool isSaving;
  final Object? saveError;

  ScoreEditState copyWith({
    int? originalScore,
    int? draftScore,
    bool? originalFinalized,
    bool? draftFinalized,
    String? rawDraft,
    String? validationError,
    bool? isDirty,
    bool? isSaving,
    Object? saveError,
  }) {
    return ScoreEditState(
      studentId: studentId,
      originalScore: originalScore ?? this.originalScore,
      draftScore: draftScore ?? this.draftScore,
      originalFinalized: originalFinalized ?? this.originalFinalized,
      draftFinalized: draftFinalized ?? this.draftFinalized,
      rawDraft: rawDraft ?? this.rawDraft,
      validationError: validationError,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError,
    );
  }
}
