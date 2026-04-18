import 'package:flutter/material.dart';
import 'logo_widget.dart';
import 'book_flight_screen.dart';
import 'booking_status_widget.dart';

import 'booked_flights_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    } else {
      _loadAircraftListFromPrefs();
    }
    if (widget.homeAirfield != null) {
      homeAirfield = widget.homeAirfield;
    } else {
      _loadHomeAirfieldFromPrefs();
    }
  }

  Future<void> _loadAircraftListFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aircraftList') ?? '';
    if (raw.isNotEmpty) {
      // crude deserialization: each aircraft is a map string
      final items = raw.split('|');
      aircraftList = items.map((item) {
        final regMatch = RegExp(r'registration: ([^,}]*)').firstMatch(item);
        final typeMatch = RegExp(r'type: ([^,}]*)').firstMatch(item);
        return {
          'registration': regMatch != null ? regMatch.group(1) : '',
          'type': typeMatch != null ? typeMatch.group(1) : '',
        };
      }).toList();
      setState(() {});
    }
  }

  Future<void> _loadHomeAirfieldFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    var ha = prefs.getString('homeAirfield');
    // Fix: CSV bug may have stored "no"/"yes" (scheduled_service) instead of ICAO
    if (ha != null && (ha.toLowerCase() == 'no' || ha.toLowerCase() == 'yes')) {
      ha = null;
      // Try name-based fallback
      final name = prefs.getString('homeAirfieldName')?.toUpperCase() ?? '';
      if (name.contains('NORTH WEALD')) {
        ha = 'EGSX';
        await prefs.setString('homeAirfield', ha!);
      }
    }
    if (ha != null && ha.isNotEmpty) {
      setState(() {
        homeAirfield = ha;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('HOME: HomeScreen build called');
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
            // BookingStatusWidget removed for cleaner UI
            ElevatedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Book a Flight'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                print('HOME: Book a Flight button pressed');
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
                print('HOME: Booked Flights button pressed');
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
                print('HOME: Flight Log button pressed');
                Navigator.of(context).pushNamed('/flight-log');
              },
            ),
          ],
        ),
      ),
    );
  }
}
