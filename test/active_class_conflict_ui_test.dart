import 'package:cpr_instructor_doc/app/app_router.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/data/repositories/class_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Create Class button checks for active class before opening create screen', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final services = AppServices(database: db);
    final router = AppRouter.buildRouter(hasClassData: true);

    // Ensure an active class exists.
    final repo = ClassRepository(db);
    final now = DateTime(2026, 1, 1, 12);
    await repo.upsertClass(
      companion: ClassRecordsCompanion(
        id: const Value('c1'),
        className: const Value('Alpha Class'),
        courseType: const Value(CourseType.blsProvider),
        classDate: Value(DateTime(2026, 1, 1)),
        location: const Value('Room 101'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      makeActiveIfNone: true,
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open class selector.
    await tester.tap(find.byTooltip('Current class'));
    await tester.pumpAndSettle();

    // Tap create another class, expect conflict sheet.
    await tester.tap(find.text('Create another class'));
    await tester.pumpAndSettle();

    expect(find.text('Active class exists'), findsOneWidget);
    expect(find.text('Alpha Class'), findsOneWidget);
    expect(find.textContaining('Room 101'), findsOneWidget);
    expect(find.text('Finalize Current Class'), findsOneWidget);

    // Cancel closes.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Active class exists'), findsNothing);
  });
}
