import 'package:cpr_instructor_doc/app/app_router.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/classes/todays_class_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 2 routes resolve without blank screens', (tester) async {
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

    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/today');

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AppScope(services: services, child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TodaysClassScreen), findsOneWidget);
    await db.close();
  });
}
