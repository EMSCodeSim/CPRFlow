import 'package:cpr_instructor_doc/app/app_router.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/app/app_services.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Unknown route shows Not Found screen', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final services = AppServices(database: db);
    final router = AppRouter.buildRouter(hasClassData: true);
    router.go('/this-route-does-not-exist');

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
    expect(find.text('Not Found'), findsOneWidget);
    expect(find.textContaining('this-route-does-not-exist'), findsOneWidget);
  });
}
