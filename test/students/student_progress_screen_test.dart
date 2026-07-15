import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/students/student_progress_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Student Progress renders core sections', (tester) async {
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
      AppScope(services: services, child: const MaterialApp(home: StudentProgressScreen(studentId: 's1'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Student'), findsWidgets);
    expect(find.text('Adult Checklist'), findsOneWidget);
    await db.close();
  });
}
