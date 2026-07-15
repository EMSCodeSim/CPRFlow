import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/classes/class_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('New required test defaults passing score to 84', (tester) async {
    final db = AppDatabase.inMemory();
    final services = AppServices(database: db)..wireCompletionService();

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ClassEditScreen(classId: null)),
      ),
    );

    await tester.pumpAndSettle();
    // Enable Written Test Required.
    await tester.tap(find.text('Written Test Required'));
    await tester.pumpAndSettle();

    final passingField = find.widgetWithText(TextFormField, 'Passing Score');
    expect(passingField, findsOneWidget);
    expect((tester.widget<TextFormField>(passingField).controller?.text ?? ''), '84');

    await db.close();
  });
}
