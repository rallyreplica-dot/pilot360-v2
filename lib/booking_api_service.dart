import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingApiService {
  static const String baseUrl = 'https://skycommand-api.onrender.com';

  static Future<List<Map<String, dynamic>>> fetchBookings() async {
    final response = await http.get(Uri.parse('$baseUrl/api/flight-bookings'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch bookings: \\${response.statusCode}');
    }
  }
}
