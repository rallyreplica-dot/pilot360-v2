import 'package:flutter/material.dart';
import 'logo_widget.dart';
import 'book_flight_screen.dart';
import 'flight_log_page.dart';
import 'booked_flights_page.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, String?>>? aircraftList;
  final String? homeAirfield;
  const HomeScreen({super.key, this.aircraftList, this.homeAirfield});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String?>> aircraftList = [];
  String? homeAirfield;

  @override
  void initState() {
    super.initState();
    if (widget.aircraftList != null) {
      aircraftList = widget.aircraftList!;
    }
    if (widget.homeAirfield != null) {
      homeAirfield = widget.homeAirfield;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4FC3F7),
      appBar: AppBar(
        title: const Text('Pilot360'),
        backgroundColor: const Color(0xFF4FC3F7),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Pilot360Logo(width: 300, height: 300),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Book a Flight'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BookFlightScreen(
                      aircraftList: aircraftList,
                      homeAirfield: homeAirfield,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Booked Flights'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BookedFlightsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.book),
              label: const Text('Flight Log'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed('/flight-log');
              },
            ),
          ],
        ),
      ),
    );
  }
}
