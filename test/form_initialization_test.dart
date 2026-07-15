import 'dart:async';

import 'package:cpr_instructor_doc/app/app_router.dart';
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
import 'package:cpr_instructor_doc/ui/widgets/keyboard_safe_save_bar.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Create Class opens without inherited-widget lifecycle errors', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final services = AppServices(database: db);
    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/class/edit?mode=create');

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(routerConfig: router, theme: ThemeData(useMaterial3: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(KeyboardSafeSaveBar), findsOneWidget);
  });

  testWidgets('Edit Class loads saved values and loader runs once', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final repo = ClassRepository(db);
    final now = DateTime(2026, 1, 1, 12);
    await repo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const Value('c1'),
        className: const Value('Loaded Class'),
        courseType: const Value(CourseType.blsProvider),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/class/edit?id=c1');
    final services = AppServices(database: db);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(routerConfig: router, theme: ThemeData(useMaterial3: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loaded Class'), findsOneWidget);
  });

  testWidgets('Leaving class edit before load completes does not throw setState after dispose', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final slowRepo = _SlowClassRepository(db, delay: const Duration(milliseconds: 300));
    final services = AppServices.custom(
      database: db,
      classRepository: slowRepo,
      studentRepository: StudentRepository(db),
      checklistRepository: ChecklistRepository(db),
      ccfRepository: CcfRepository(db),
      scoreRepository: ScoreRepository(db),
      documentRepository: DocumentRepository(db),
      studentCompletionService: StudentCompletionService.unwired()..wire(checklistRepository: ChecklistRepository(db), ccfRepository: CcfRepository(db)),
    );
    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/class/edit?id=c_slow');

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(routerConfig: router, theme: ThemeData(useMaterial3: true)),
      ),
    );

    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();

    // Let the delayed load finish.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Student opens without inherited-widget lifecycle errors (small iPhone size)', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(750, 1334); // ~iPhone 8 logical w/2x
    binding.platformDispatcher.views.first.devicePixelRatio = 2.0;
    addTearDown(() {
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final classRepo = ClassRepository(db);
    final now = DateTime(2026, 1, 1, 12);
    await classRepo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const Value('c1'),
        className: const Value('Class'),
        courseType: const Value(CourseType.blsProvider),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    final services = AppServices(database: db);
    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/student/add');

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(routerConfig: router, theme: ThemeData(useMaterial3: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(KeyboardSafeSaveBar), findsOneWidget);
  });
}

class _SlowClassRepository extends ClassRepository {
  _SlowClassRepository(AppDatabase db, {required this.delay}) : super(db);

  final Duration delay;

  @override
  Future<ClassRecord?> getById(String id) async {
    await Future<void>.delayed(delay);
    return super.getById(id);
  }
}
