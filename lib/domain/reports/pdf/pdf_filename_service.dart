import 'package:intl/intl.dart';

class PdfFilenameService {
  const PdfFilenameService._();

  static String sanitize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'CCF_Timer_Report';
    // Windows/macOS/iOS/Android safe-ish subset.
    final cleaned = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? 'CCF_Timer_Report' : cleaned;
  }

  static String classDateTag(DateTime? date) {
    if (date == null) return 'Unknown_Date';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String ensurePdfExtension(String filename) => filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf';
}
