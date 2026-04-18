import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingApiService {
  static const String baseUrl = 'http://localhost:41000';

  static Future<List<Map<String, dynamic>>> fetchBookings() async {
    final response = await http.get(Uri.parse('$baseUrl/api/flight-bookings'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch bookings: \\${response.statusCode}');
    }
  }

  /// Update the status of a booking by ID. Returns true if successful.
  static Future<bool> updateBookingStatus(String bookingId, String status) async {
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
}
