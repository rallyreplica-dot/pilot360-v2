/// Maps common airline telephony designators (e.g. "SPEEDBIRD") to ICAO codes (e.g. "BAW").
/// The user can type either the telephony name or the ICAO code followed by a flight number.
/// Example: "speedbird123" → "BAW123", "BAW123" → "BAW123"
class CallsignLookup {
  static const Map<String, String> _telephonyToIcao = {
    'SPEEDBIRD': 'BAW',
    'SHAMROCK': 'EIN',
    'RYANAIR': 'RYR',
    'EASYJET': 'EZY',
    'EASY': 'EZY',
    'JET2': 'EXS',
    'CHANNEX': 'EXS',
    'VIRGIN': 'VIR',
    'TUI': 'TOM',
    'THOMSONFLY': 'TOM',
    'LOGANAIR': 'LOG',
    'EASTERN': 'EZE',
    'STOBART': 'EDY',
    'FLYBE': 'BEE',
    'JERSEY': 'JEA',
    'SHUTTLE': 'SHT',
    'MIDLAND': 'BMA',
    'CALEDONIAN': 'BCA',
    'MONARCH': 'MON',
    'TITAN': 'AWC',
    'ATLANTIC': 'NPT',
    'CITYFLYER': 'CFE',
    'OSCAR': 'OCY',
    'ENVOY': 'ENY',
    'CACTUS': 'AWE',
    'AMERICAN': 'AAL',
    'UNITED': 'UAL',
    'DELTA': 'DAL',
    'SOUTHWEST': 'SWA',
    'JETBLUE': 'JBU',
    'LUFTHANSA': 'DLH',
    'AIRFRANS': 'AFR',
    'KLM': 'KLM',
    'IBERIA': 'IBE',
    'ALITALIA': 'AZA',
    'SCANDINAVIAN': 'SAS',
    'FINNAIR': 'FIN',
    'AUSTRIAN': 'AUA',
    'SWISS': 'SWR',
    'SABENA': 'SAB',
    'AEROFLOT': 'AFL',
    'QANTAS': 'QFA',
    'EMIRATES': 'UAE',
    'ETIHAD': 'ETD',
    'QATAR': 'QTR',
    'CATHAY': 'CPA',
    'SINGAPORE': 'SIA',
    'THAI': 'THA',
    'JAPAN AIR': 'JAL',
    'ANA': 'ANA',
    'KOREAN AIR': 'KAL',
    'AIR CANADA': 'ACA',
    'MAPLE': 'ACA',
    'CLIPPER': 'PAA',
    'SPRINGBOK': 'SAA',
    'AVIANCA': 'AVA',
    'AEROMEXICO': 'AMX',
    'COPA': 'CMP',
    'LATAM': 'LAN',
    'GOL': 'GLO',
    'AZUL': 'AZU',
    'WIZZAIR': 'WZZ',
    'WIZZ': 'WZZ',
    'NORWEGIAN': 'NAX',
    'ICELANDAIR': 'ICE',
    'CONDOR': 'CFG',
    'EUROWINGS': 'EWG',
    'TRANSAVIA': 'TRA',
    'VOLOTEA': 'VOE',
    'VUELING': 'VLG',
    'TAP': 'TAP',
    'AEGEAN': 'AEE',
    'PEGASUS': 'PGT',
    'TURKISH': 'THY',
    'ELAL': 'ELY',
    'SUNEXPRESS': 'SXS',
    'ROYAL AIR MAROC': 'RAM',
    'TUNISAIR': 'TAR',
    'EGYPTAIR': 'MSR',
    'KENYA': 'KQA',
    'ETHIOPIAN': 'ETH',
    'AIRLINK': 'LNK',
    'KULULA': 'MNX',
    'MANGO': 'MNO',
  };

  /// Reverse map: ICAO code → telephony designator
  static final Map<String, String> _icaoToTelephony = {
    for (final entry in _telephonyToIcao.entries) entry.value: entry.key,
  };

  /// Format a raw callsign input into proper ICAO format.
  /// Examples:
  ///   "speedbird123" → "BAW123"
  ///   "BAW123" → "BAW123"
  ///   "GAWFJ" → "GAWFJ" (no match, returned as-is uppercase)
  static String format(String input) {
    input = input.trim().toUpperCase();
    if (input.isEmpty) return '';

    // Try to split into word part and number part
    final match = RegExp(r'^([A-Z\s]+?)(\d+)$').firstMatch(input);
    if (match != null) {
      final word = match.group(1)!.trim();
      final number = match.group(2)!;

      // Check if the word part is a telephony designator
      if (_telephonyToIcao.containsKey(word)) {
        return '${_telephonyToIcao[word]}$number';
      }
      // Check if it's already an ICAO code
      if (_icaoToTelephony.containsKey(word)) {
        return '$word$number';
      }
    }

    // Check if the whole input (without numbers) is a known ICAO code
    final icaoMatch = RegExp(r'^([A-Z]{2,3})(\d+)$').firstMatch(input);
    if (icaoMatch != null) {
      final code = icaoMatch.group(1)!;
      final number = icaoMatch.group(2)!;
      if (_icaoToTelephony.containsKey(code)) {
        return '$code$number';
      }
    }

    // No match — return as-is (uppercase)
    return input;
  }

  /// Get the ICAO code for a telephony designator, or null if not found.
  static String? icaoFromTelephony(String telephony) {
    return _telephonyToIcao[telephony.trim().toUpperCase()];
  }

  /// Get the telephony designator for an ICAO code, or null if not found.
  static String? telephonyFromIcao(String icao) {
    return _icaoToTelephony[icao.trim().toUpperCase()];
  }
}
