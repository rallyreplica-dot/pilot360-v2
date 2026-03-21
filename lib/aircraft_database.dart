import 'package:flutter/services.dart' show rootBundle;

class AircraftDatabase {
  final Map<String, String> _regToType = {};
  final List<String> _dbFiles = [
    'assets/report.txt',
    'assets/heli.txt',
    'assets/turboexec.txt',
  ];

  /// Public getter for registration-to-type map
  Map<String, String> get regToType => _regToType;

  AircraftDatabase();

  Future<void> load() async {
    _regToType.clear();
    for (final dbFile in _dbFiles) {
      try {
        final txtString = await rootBundle.loadString(dbFile);
        final lines = txtString
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (lines.length < 2) continue;
        final header = lines[0].split(RegExp(r'\s+')).map((e) => e.trim()).toList();
        final regIdx = header.indexOf('currentid');
        final typeIdx = header.indexOf('ICAO_type');
        if (regIdx == -1 || typeIdx == -1) continue;
        for (var i = 1; i < lines.length; i++) {
          final fields = lines[i].split(RegExp(r'\s+'));
          if (fields.length <= typeIdx || fields.length <= regIdx) continue;
          final reg = fields[regIdx].trim();
          final type = fields[typeIdx].trim();
          if (reg.isNotEmpty && type.isNotEmpty) {
            _regToType[reg] = type;
          }
        }
      } catch (e) {
        // Ignore missing files or load errors
      }
    }
  }

  String? getTypeForRegistration(String registration) {
    final reg = registration.trim().toUpperCase();
    // Try exact match first
    String? type = _regToType[reg];
    if (type != null) return type;
    // Try removing hyphens if present
    final regNoHyphen = reg.replaceAll('-', '');
    // Search for a key that matches ignoring hyphens
    type = _regToType[regNoHyphen];
    if (type != null) return type;
    // Try searching all keys for a match ignoring hyphens
    for (final entry in _regToType.entries) {
      if (entry.key.replaceAll('-', '') == regNoHyphen) {
        return entry.value;
      }
    }
    return null;
  }
}
