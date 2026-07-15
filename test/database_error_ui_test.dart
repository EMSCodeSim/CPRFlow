import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/ccf_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/checklist_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/document_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/score_repository.dart';
import 'package:cpr_instructor_doc/data/repositories/student_repository.dart';
import 'package:cpr_instructor_doc/domain/completion/student_completion_service.dart';
import 'package:cpr_instructor_doc/ui/home/home_screen.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home active-class stream error shows DatabaseErrorPanel', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final services = AppServices.custom(
      database: db,
      classRepository: _ErrorClassRepository(),
      studentRepository: StudentRepository(db),
      checklistRepository: ChecklistRepository(db),
      ccfRepository: CcfRepository(db),
      scoreRepository: ScoreRepository(db),
      documentRepository: DocumentRepository(db),
      studentCompletionService: StudentCompletionService.unwired()..wire(checklistRepository: ChecklistRepository(db), ccfRepository: CcfRepository(db)),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(DatabaseErrorPanel), findsOneWidget);
    expect(find.textContaining('No active class'), findsNothing);
    expect(find.text('Technical details'), findsOneWidget);
  });

  testWidgets('Technical details are hidden by default and can be expanded', (tester) async {
    final widget = MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: DatabaseErrorPanel(
          message: 'Class data could not be loaded.',
          error: StateError('boom'),
          onRetry: () {},
          onOpenRecovery: () {},
        ),
      ),
    );

    await tester.pumpWidget(widget);
    expect(find.text('boom'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsOneWidget);
  });
}

class _ErrorClassRepository extends ClassRepository {
  _ErrorClassRepository() : super(null);

  @override
  Stream<ClassRecord?> watchActiveClass() => Stream<ClassRecord?>.error(StateError('db failed'));
}
