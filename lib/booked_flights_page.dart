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
    return Scaffold(
      appBar: AppBar(title: const Text('Booked Flights')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('View Calendar'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CalendarBookingsPage(),
                  ),
                );
                // Refresh bookings after returning
                loadBookings();
              },
            ),
          ),
          // Calendar is now the only view for bookings
        ],
      ),
    );
  }
}
