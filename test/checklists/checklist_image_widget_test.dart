import 'package:cpr_instructor_doc/ui/checklists/checklist_image.dart';
import 'package:cpr_instructor_doc/ui/checklists/checklist_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChecklistImage shows real asset and opens viewer on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChecklistImage(
            assetPath: 'assets/bls/01_scene_safety.png',
            title: 'Scene safety',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistImageViewer), findsOneWidget);
    expect(find.text('Scene safety'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('ChecklistImage shows placeholder when assetPath is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChecklistImage(assetPath: null, title: 'Missing'),
        ),
      ),
    );
    expect(find.text('Approved checklist image not yet added.'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}
