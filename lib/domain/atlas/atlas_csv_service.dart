import 'dart:convert';

class AtlasCsvService {
  const AtlasCsvService();
  String encode({required List<String> headers, required List<List<String>> rows}) {
    final out = StringBuffer()..writeln(headers.map(_escape).join(','));
    for (final row in rows) { out.writeln(row.map(_escape).join(',')); }
    return '\uFEFF${out.toString()}';
  }
  List<String> decodeFirstRow(String csv) {
    final lines = const LineSplitter().convert(csv.replaceFirst('\uFEFF', ''));
    return lines.isEmpty ? const [] : _parseLine(lines.first);
  }
  String _escape(String value) => value.contains(RegExp('[,"\r\n]')) ? '"${value.replaceAll('"', '""')}"' : value;
  List<String> _parseLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') { current.write('"'); i++; } else { quoted = !quoted; }
      } else if (ch == ',' && !quoted) { result.add(current.toString()); current.clear(); } else { current.write(ch); }
    }
    result.add(current.toString());
    return result;
  }
}
