import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  final prefs = await SharedPreferences.getInstance();
  final bookings = prefs.getStringList('flightBookings') ?? [];
  print('Bookings in SharedPreferences:');
  for (final raw in bookings) {
    print(raw);
    try {
      final booking = jsonDecode(raw);
      print('Decoded:');
      print(booking);
    } catch (e) {
      print('Failed to decode: $e');
    }
  }
}
