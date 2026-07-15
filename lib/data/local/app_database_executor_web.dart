import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<QueryExecutor> openExecutor() async {
  // On Web we use Drift's WebDatabase (IndexedDB + sql.js). We load sql.js
  // via a <script> tag in web/index.html.
  return WebDatabase('ccf_timer_v1');
}

QueryExecutor openTestExecutor() => WebDatabase('ccf_timer_test');
