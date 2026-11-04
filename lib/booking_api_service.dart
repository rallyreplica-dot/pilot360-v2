import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class BookingApiService {
  static const String baseUrl = 'http://localhost:41000';

  static String generateJourneyId() {
    final randomPart = Random.secure().nextInt(1 << 30).toRadixString(16);
    return 'pilot360-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  static Map<String, dynamic> buildSubmissionPayload({
    required Map<String, dynamic> booking,
    required String departure,
    required String destination,
    required String fromIcao,
    required String toIcao,
  }) {
    final journeyId = booking['journeyId']?.toString().trim() ?? '';
    final journeyLeg =
        booking['journeyLeg']?.toString().trim().toLowerCase() ?? '';
    if (journeyId.isEmpty || !['outbound', 'return'].contains(journeyLeg)) {
      throw ArgumentError('A Pilot360 booking must have a linked journey leg');
    }

    return {
      'aircraft': booking['aircraft'],
      'callsign': booking['callsign'],
      'departure': departure,
      'arrival': destination,
      'from': fromIcao,
      'to': toIcao,
      'pob': booking['pob'] ?? '0',
      'type': booking['typeOfFlight'] ?? '',
      'etd': booking['etd'],
      'eta': booking['eta'],
      'date': booking['date'],
      'journeyId': journeyId,
      'journeyLeg': journeyLeg,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchBookings({
    bool includeCancelled = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/flight-bookings').replace(
      queryParameters: includeCancelled ? {'includeCancelled': 'true'} : null,
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch bookings: \\${response.statusCode}');
    }
  }

  /// Update the status of a booking by ID. Returns true if successful.
  static Future<bool> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    final url = Uri.parse('$baseUrl/api/flight-bookings/$bookingId/status');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> cancelBooking(
    String bookingId,
    String journeyLeg,
  ) async {
    final url = Uri.parse('$baseUrl/api/flight-bookings/$bookingId/cancel');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'journeyLeg': journeyLeg}),
    );
    final result = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200) {
      return {'error': result['error'] ?? 'Failed to cancel booking'};
    }
    return result;
  }
}
