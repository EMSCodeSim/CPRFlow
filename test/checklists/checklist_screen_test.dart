import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/domain/checklists/checklist_registry.dart';
import 'package:cpr_instructor_doc/ui/checklists/checklist_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Checklist screen shows safe placeholder when image missing', (tester) async {
    final db = AppDatabase.inMemory();
    final services = AppServices(database: db)..wireCompletionService();
    final now = DateTime(2025, 1, 1);
    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.studentRecords).insert(
      StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ChecklistScreen(studentId: 's1', checklistType: ChecklistType.adult)),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Approved checklist image not yet added.'), findsOneWidget);
    await db.close();
  });

  testWidgets('Checklist notes remain attached to correct item when navigating quickly', (tester) async {
    final db = AppDatabase.inMemory();
    final services = AppServices(database: db)..wireCompletionService();
    final now = DateTime(2025, 1, 1);
    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.studentRecords).insert(
      StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ChecklistScreen(studentId: 's1', checklistType: ChecklistType.adult)),
      ),
    );
    await tester.pumpAndSettle();

    final def = ChecklistRegistry.definitionFor(ChecklistType.adult);
    final item1 = def.items.first;
    final item2 = def.items[1];

    await tester.enterText(find.byKey(const Key('checklistNotesField')), 'Note for item 1');
    // Immediately navigate forward; this should flush pending notes to item 1.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Next'));
    await tester.pumpAndSettle();

    final attempt = await (db.select(db.checklistAttempts)
          ..where((t) => t.studentId.equals('s1') & t.checklistType.equalsValue(ChecklistType.adult) & t.finalized.equals(false))
          ..limit(1))
        .getSingle();

    final r1 = await (db.select(db.checklistItemResults)
          ..where((t) => t.attemptId.equals(attempt.id) & t.itemId.equals(item1.id))
          ..limit(1))
        .getSingleOrNull();
    final r2 = await (db.select(db.checklistItemResults)
          ..where((t) => t.attemptId.equals(attempt.id) & t.itemId.equals(item2.id))
          ..limit(1))
        .getSingleOrNull();

    expect(r1?.notes, 'Note for item 1');
    expect(r2?.notes, anyOf(isNull, isEmpty));
    await db.close();
  });

  testWidgets('Checklist screen does not overflow on small phone with keyboard open', (tester) async {
    final db = AppDatabase.inMemory();
    final services = AppServices(database: db)..wireCompletionService();
    final now = DateTime(2025, 1, 1);
    await db.into(db.classRecords).insert(
      ClassRecordsCompanion(
        id: const drift.Value('c1'),
        className: const drift.Value('C1'),
        courseType: const drift.Value(CourseType.blsProvider),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.into(db.studentRecords).insert(
      StudentRecordsCompanion(
        id: const drift.Value('s1'),
        classId: const drift.Value('c1'),
        displayName: const drift.Value('Student'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568); // iPhone SE-ish
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ChecklistScreen(studentId: 's1', checklistType: ChecklistType.adult)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checklistNotesField')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Finish Checklist'), findsOneWidget);
    await db.close();
  });
}
