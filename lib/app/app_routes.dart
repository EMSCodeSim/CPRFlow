class AppRoutes {
  static const home = '/';
  static const classEdit = '/class/edit';
  static const studentAdd = '/student/add';
  static const studentEdit = '/student/edit';

  // Phase 2
  static const today = '/today';
  static const studentProgress = '/today/student';
  static const checklist = '/today/checklist';
  static const ccfTimer = '/ccf-timer';
  static const studentCcf = '/today/ccf';
  static const scores = '/today/scores';

  // Phase 3
  static const finalizeClass = '/today/finalize';
  static const archive = '/archive';
  static const archivedClassDetail = '/archive/detail';
  static const finalizationSuccess = '/today/finalize/success';

  // Phase 4
  static const todayReports = '/today/reports';
  static const archiveReports = '/archive'; // canonical: /archive/:classId/reports
  static const todayAtlas = '/today/atlas';
  static const archiveAtlas = '/archive'; // canonical: /archive/:classId/atlas
  static const atlasTemplateSettings = '/atlas/templates';
  static const pdfPreview = '/reports/pdf-preview';

  // Phase 5
  static const classDocuments = '/today/documents';
  static const archivedDocuments = '/archive'; // canonical: /archive/:snapshotId/documents
  static const documentPreview = '/documents/preview';
}
