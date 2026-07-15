import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/score_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';

/// Holds initialized app-wide dependencies.
///
/// Phase 1: local-only Drift database + repositories.
class AppServices {
  AppServices({required this.database})
      : classRepository = ClassRepository(database),
        studentRepository = StudentRepository(database),
        checklistRepository = ChecklistRepository(database),
        ccfRepository = CcfRepository(database),
        scoreRepository = ScoreRepository(database),
        studentCompletionService = StudentCompletionService.unwired();

  /// Must be called after the default constructor so [studentCompletionService]
  /// can reference the same repository instances.
  void wireCompletionService() => studentCompletionService.wire(
        checklistRepository: checklistRepository,
        ccfRepository: ccfRepository,
      );

  /// Advanced/test-only constructor to inject repositories.
  AppServices.custom({
    required this.database,
    required this.classRepository,
    required this.studentRepository,
    required this.checklistRepository,
    required this.ccfRepository,
    required this.scoreRepository,
    required this.studentCompletionService,
  });

  /// A running Drift database instance.
  ///
  /// When null, the app is running in "Open Without Class Data" mode.
  final AppDatabase? database;

  final ClassRepository classRepository;
  final StudentRepository studentRepository;
  final ChecklistRepository checklistRepository;
  final CcfRepository ccfRepository;
  final ScoreRepository scoreRepository;
  final StudentCompletionService studentCompletionService;

  bool get hasClassData => database != null;

  Future<void> dispose() async {
    await database?.close();
  }

  static AppServices withoutDatabase() => AppServices(database: null);
}
