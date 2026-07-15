import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/classes/class_edit_screen.dart';
import 'package:cpr_instructor_doc/ui/classes/todays_class_screen.dart';
import 'package:cpr_instructor_doc/ui/ccf/ccf_timer_screen.dart';
import 'package:cpr_instructor_doc/ui/checklists/checklist_screen.dart';
import 'package:cpr_instructor_doc/ui/home/home_screen.dart';
import 'package:cpr_instructor_doc/ui/finalization/finalize_class_wizard_screen.dart';
import 'package:cpr_instructor_doc/ui/finalization/finalization_success_screen.dart';
import 'package:cpr_instructor_doc/ui/archive/archive_screen.dart';
import 'package:cpr_instructor_doc/ui/archive/archived_class_detail_screen.dart';
import 'package:cpr_instructor_doc/ui/reports/reports_center_screen.dart';
import 'package:cpr_instructor_doc/ui/reports/pdf_preview_screen.dart';
import 'package:cpr_instructor_doc/ui/atlas/atlas_export_review_screen.dart';
import 'package:cpr_instructor_doc/ui/atlas/atlas_template_settings_screen.dart';
import 'package:cpr_instructor_doc/ui/documents/class_documents_screen.dart';
import 'package:cpr_instructor_doc/ui/documents/document_preview_screen.dart';
import 'package:cpr_instructor_doc/ui/documents/document_preview_request.dart';
import 'package:cpr_instructor_doc/ui/routes/safe_error_screen.dart';
import 'package:cpr_instructor_doc/ui/routes/unknown_route_screen.dart';
import 'package:cpr_instructor_doc/ui/scores/score_entry_screen.dart';
import 'package:cpr_instructor_doc/ui/students/student_edit_screen.dart';
import 'package:cpr_instructor_doc/ui/students/student_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static GoRouter buildRouter({required bool hasClassData}) => GoRouter(
    initialLocation: AppRoutes.home,
    errorBuilder: (context, state) => UnknownRouteScreen(location: state.uri.toString()),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.classEdit,
        name: 'classEdit',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: UnknownRouteScreen(location: AppRoutes.classEdit));
          }
          final classId = state.uri.queryParameters['id'];
          return MaterialPage(child: ClassEditScreen(classId: classId));
        },
      ),
      GoRoute(
        path: AppRoutes.studentAdd,
        name: 'studentAdd',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: UnknownRouteScreen(location: AppRoutes.studentAdd));
          }
          return const MaterialPage(child: StudentEditScreen(studentId: null));
        },
      ),
      GoRoute(
        path: '${AppRoutes.studentEdit}/:id',
        name: 'studentEdit',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: UnknownRouteScreen(location: AppRoutes.studentEdit));
          }
          final id = state.pathParameters['id'];
          return MaterialPage(child: StudentEditScreen(studentId: id));
        },
      ),

      GoRoute(
        path: AppRoutes.today,
        name: 'today',
        pageBuilder: (context, state) {
          if (!hasClassData) return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Today\'s Class is unavailable in recovery mode.'));
          return const MaterialPage(child: TodaysClassScreen());
        },
      ),
      GoRoute(
        path: '${AppRoutes.studentProgress}/:id',
        name: 'studentProgress',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Student Progress is unavailable in recovery mode.'));
          }
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing student', message: 'No student ID provided.', onRetryLocation: AppRoutes.today));
          }
          return MaterialPage(child: StudentProgressScreen(studentId: id));
        },
      ),
      GoRoute(
        path: '${AppRoutes.checklist}/:studentId',
        name: 'checklist',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Checklists are unavailable in recovery mode.'));
          }
          final studentId = state.pathParameters['studentId'];
          final typeParam = state.uri.queryParameters['type'];
          if (studentId == null || studentId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing student', message: 'No student ID provided.', onRetryLocation: AppRoutes.today));
          }
          final type = typeParam == 'infantChild' ? ChecklistType.infantChild : ChecklistType.adult;
          return MaterialPage(child: ChecklistScreen(studentId: studentId, checklistType: type));
        },
      ),
      GoRoute(
        path: AppRoutes.ccfTimer,
        name: 'ccfTimer',
        pageBuilder: (context, state) => const MaterialPage(child: CcfTimerScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.studentCcf}/:studentId',
        name: 'studentCcf',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Student CCF is unavailable in recovery mode.'));
          }
          final studentId = state.pathParameters['studentId'];
          if (studentId == null || studentId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing student', message: 'No student ID provided.', onRetryLocation: AppRoutes.today));
          }
          // The screen itself will bind to the active class.
          return MaterialPage(child: _StudentBoundCcfScreen(studentId: studentId));
        },
      ),
      GoRoute(
        path: AppRoutes.scores,
        name: 'scores',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Scores are unavailable in recovery mode.'));
          }
          return const MaterialPage(child: ScoreEntryScreen());
        },
      ),

      // Phase 3
      GoRoute(
        path: AppRoutes.finalizeClass,
        name: 'finalizeClass',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Finalization is unavailable in recovery mode.'));
          }
          return const MaterialPage(child: FinalizeClassWizardScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.finalizationSuccess,
        name: 'finalizationSuccess',
        pageBuilder: (context, state) {
          final snapshotId = state.uri.queryParameters['snapshotId'];
          if (snapshotId == null || snapshotId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.home));
          }
          return MaterialPage(child: FinalizationSuccessScreen(snapshotId: snapshotId));
        },
      ),
      GoRoute(
        path: AppRoutes.archive,
        name: 'archive',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Archive is unavailable in recovery mode.'));
          }
          return const MaterialPage(child: ArchiveScreen());
        },
      ),
      GoRoute(
        path: '${AppRoutes.archivedClassDetail}/:snapshotId',
        name: 'archivedClassDetail',
        pageBuilder: (context, state) {
          final snapshotId = state.pathParameters['snapshotId'];
          if (snapshotId == null || snapshotId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.archive));
          }
          return MaterialPage(child: ArchivedClassDetailScreen(snapshotId: snapshotId));
        },
      ),

      // Phase 4
      GoRoute(
        path: AppRoutes.todayReports,
        name: 'todayReports',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Reports are unavailable in recovery mode.'));
          }
          final classId = state.uri.queryParameters['classId'];
          if (classId == null || classId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing class', message: 'No class ID provided.', onRetryLocation: AppRoutes.today));
          }
          return MaterialPage(child: ReportsCenterScreen.live(classId: classId));
        },
      ),
      GoRoute(
        path: '/archive/:classId/reports',
        name: 'archiveReports',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Reports are unavailable in recovery mode.'));
          }
          final snapshotId = state.pathParameters['classId'];
          if (snapshotId == null || snapshotId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.archive));
          }
          return MaterialPage(child: ReportsCenterScreen.snapshot(snapshotId: snapshotId));
        },
      ),
      GoRoute(
        path: AppRoutes.pdfPreview,
        name: 'pdfPreview',
        pageBuilder: (context, state) => MaterialPage(child: PdfPreviewScreen(request: state.extra)),
      ),

      // Phase 5
      GoRoute(
        path: AppRoutes.classDocuments,
        name: 'classDocuments',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Documents are unavailable in recovery mode.'));
          }
          final classId = state.uri.queryParameters['classId'];
          if (classId == null || classId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing class', message: 'No class ID provided.', onRetryLocation: AppRoutes.today));
          }
          final studentId = state.uri.queryParameters['studentId'];
          if (studentId != null && studentId.isNotEmpty) {
            return MaterialPage(child: ClassDocumentsScreen.student(classId: classId, studentId: studentId, readOnly: false));
          }
          return MaterialPage(child: ClassDocumentsScreen.live(classId: classId));
        },
      ),
      GoRoute(
        path: '/archive/:snapshotId/documents',
        name: 'archivedDocuments',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Documents are unavailable in recovery mode.'));
          }
          final snapshotId = state.pathParameters['snapshotId'];
          if (snapshotId == null || snapshotId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.archive));
          }
          return MaterialPage(child: ClassDocumentsScreen.snapshot(snapshotId: snapshotId));
        },
      ),
      GoRoute(
        path: AppRoutes.documentPreview,
        name: 'documentPreview',
        pageBuilder: (context, state) {
          final req = state.extra;
          if (req is! DocumentPreviewRequest) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing document', message: 'No preview request provided.'));
          }
          return MaterialPage(child: DocumentPreviewScreen(request: req));
        },
      ),

      GoRoute(
        path: AppRoutes.atlasTemplateSettings,
        name: 'atlasTemplateSettings',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Atlas template settings are unavailable in recovery mode.'));
          }
          return const MaterialPage(child: AtlasTemplateSettingsScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.todayAtlas,
        name: 'todayAtlas',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Atlas export is unavailable in recovery mode.'));
          }
          final classId = state.uri.queryParameters['classId'];
          if (classId == null || classId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing class', message: 'No class ID provided.', onRetryLocation: AppRoutes.today));
          }
          return MaterialPage(child: AtlasExportReviewScreen.live(classId: classId));
        },
      ),
      GoRoute(
        path: '/archive/:classId/atlas',
        name: 'archiveAtlas',
        pageBuilder: (context, state) {
          if (!hasClassData) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Class data disabled', message: 'Atlas export is unavailable in recovery mode.'));
          }
          final snapshotId = state.pathParameters['classId'];
          if (snapshotId == null || snapshotId.isEmpty) {
            return const NoTransitionPage(child: SafeErrorScreen(title: 'Missing snapshot', message: 'No snapshot ID provided.', onRetryLocation: AppRoutes.archive));
          }
          return MaterialPage(child: AtlasExportReviewScreen.snapshot(snapshotId: snapshotId));
        },
      ),
    ],
    redirect: (context, state) {
      // Defensive: if user deep-links into class/student routes while class data disabled.
      if (!hasClassData) {
        final loc = state.matchedLocation;
        if (loc != AppRoutes.home) return AppRoutes.home;
      }
      return null;
    },
    observers: [
      _RouteObserver(),
    ],
  );
}

class _RouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Ensures AppScope is referenced (keeps analyzer from complaining about unused import
    // if routes are tree-shaken in tests).
    super.didPush(route, previousRoute);
  }
}

class _StudentBoundCcfScreen extends StatelessWidget {
  const _StudentBoundCcfScreen({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context) {
    // We keep this widget in the router layer so we can convert “active class”
    // into an explicit (classId, studentId) timer screen without extra routes.
    final services = AppScope.of(context);
    return FutureBuilder<ClassRecord?>(
      future: services.classRepository.getActiveClass(),
      builder: (context, snap) {
        final active = snap.data;
        if (snap.hasError) {
          return const SafeErrorScreen(title: 'CCF could not be opened', message: 'Active class could not be loaded.', onRetryLocation: AppRoutes.today);
        }
        if (active == null) {
          return const SafeErrorScreen(title: 'No active class', message: 'Return to Today\'s Class and try again.', onRetryLocation: AppRoutes.today);
        }
        return CcfTimerScreen(classId: active.id, studentId: studentId);
      },
    );
  }
}
