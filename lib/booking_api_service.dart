import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingApiService {
  static const String baseUrl = 'http://172.25.0.138:3000';

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
