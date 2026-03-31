import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_bookings_page.dart';

class BookedFlightsPage extends StatefulWidget {
  const BookedFlightsPage({super.key});

  @override
  State<BookedFlightsPage> createState() => _BookedFlightsPageState();
}

class _BookedFlightsPageState extends State<BookedFlightsPage> {
  List<String> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookings = prefs.getStringList('flightBookings') ?? [];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('BOOKED FLIGHTS: BookedFlightsPage build called');
    return const CalendarBookingsPage();
  }
}
