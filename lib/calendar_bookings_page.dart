
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

// Booking event model for calendar
class _BookingEvent {
  final DateTime start;
  final DateTime end;
  final String raw; // Original JSON string for editing/deleting

  _BookingEvent({required this.start, required this.end, required this.raw});
}


class CalendarBookingsPage extends StatefulWidget {
  const CalendarBookingsPage({super.key});

  @override
  State<CalendarBookingsPage> createState() => _CalendarBookingsPageState();
}

class _CalendarBookingsPageState extends State<CalendarBookingsPage> {
    Future<void> clearAllBookings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('flightBookings');
      setState(() {
        events = [];
      });
    }
  bool isLoading = true;
  List<_BookingEvent> events = [];

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final bookings = prefs.getStringList('flightBookings') ?? [];
    // Parse bookings into _BookingEvent list
    final List<_BookingEvent> loadedEvents = [];
    for (final raw in bookings) {
      try {
        final Map<String, dynamic> bookingMap = jsonDecode(raw);
        final type = (bookingMap['typeOfFlight'] ?? '').toString().toUpperCase();
        final dateStr = bookingMap['date'] ?? '';
        final etdStr = bookingMap['etd'] ?? '';
        int parseYear(String y) {
          if (y.length == 2) return 2000 + int.parse(y);
          if (y.length == 4) return int.parse(y);
          throw FormatException('Year must be 2 or 4 digits');
        }
        List<int>? parseDMY(String dateStr) {
          final parts = dateStr.split('/');
          if (parts.length != 3) return null;
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = parseYear(parts[2]);
          return [day, month, year];
        }
        List<int> parseTime(String timeStr) {
          timeStr = timeStr.trim();
          if (timeStr.contains(':')) {
            final parts = timeStr.split(':');
            final hour = int.parse(parts[0]);
            final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
            return [hour, minute];
          } else if (timeStr.length == 4) {
            return [int.parse(timeStr.substring(0, 2)), int.parse(timeStr.substring(2, 4))];
          } else if (timeStr.length == 3) {
            return [int.parse(timeStr.substring(0, 1)), int.parse(timeStr.substring(1, 3))];
          } else if (timeStr.length == 2) {
            return [int.parse(timeStr), 0];
          } else if (timeStr.length == 1) {
            return [int.parse(timeStr), 0];
          } else {
            return [0, 0];
          }
        }
        if (dateStr.isNotEmpty && etdStr.isNotEmpty) {
          final dmy = parseDMY(dateStr);
          if (dmy != null) {
            final day = dmy[0], month = dmy[1], year = dmy[2];
            final etdParts = parseTime(etdStr);
            final start = DateTime(year, month, day, etdParts[0], etdParts[1]);
            final end = start.add(const Duration(hours: 1)); // Always single-day event
            final isDuplicate = loadedEvents.any((e) => e.start == start && e.end == end && e.raw == raw);
            if (!isDuplicate) {
              loadedEvents.add(_BookingEvent(start: start, end: end, raw: raw));
            }
          }
        }
      } catch (_) {}
    }
    // Debug print: show all raw bookings and parsed events
    debugPrint('Raw bookings from SharedPreferences:');
    for (final raw in bookings) {
      debugPrint(raw);
    }
    debugPrint('Parsed events:');
    for (final event in loadedEvents) {
      debugPrint('Event: start=${event.start}, end=${event.end}, raw=${event.raw}');
    }
    setState(() {
      events = loadedEvents;
      isLoading = false;
    });
  }

  String _formatBookingTimeRange(DateTime start, DateTime end) {
    String formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${formatTime(start)} - ${formatTime(end)}';
  }

  void _showDayBookingsDialog(List<_BookingEvent> dayEvents) async {
    final localContext = context;
    if (!mounted) return;
    await showModalBottomSheet(
      context: localContext,
      isScrollControlled: true,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: dayEvents.length,
        itemBuilder: (context, index) {
          final event = dayEvents[index];
          final bookingMap = Map<String, String>.from(jsonDecode(event.raw));
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking details:', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ..._filteredBookingFields(bookingMap).map((e) => Text('${e.key}: ${e.value}')),
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: localContext,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel Booking'),
                          content: const Text('Are you sure you want to cancel this booking?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        final bookings = prefs.getStringList('flightBookings') ?? [];
                        bookings.remove(event.raw);
                        await prefs.setStringList('flightBookings', bookings);
                        if (!mounted) return;
                        Navigator.pop(localContext); // Close the dialog
                        loadBookings();
                      }
                    },
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to filter booking fields for display
  List<MapEntry<String, String>> _filteredBookingFields(Map<String, String> booking) {
    final isReturnLeg = (booking['typeOfFlight']?.toUpperCase() == 'RETURN');
    final fields = <String, String>{...booking};
    if (isReturnLeg) {
      return [
        if (fields['date'] != null && fields['date']!.isNotEmpty) MapEntry('date', fields['date']!),
        if (fields['aircraft'] != null && fields['aircraft']!.isNotEmpty) MapEntry('aircraft', fields['aircraft']!),
        if (fields['departure'] != null && fields['departure']!.isNotEmpty) MapEntry('departure', fields['departure']!),
        if (fields['destination'] != null && fields['destination']!.isNotEmpty) MapEntry('destination', fields['destination']!),
        if (fields['etd'] != null && fields['etd']!.isNotEmpty) MapEntry('eta', fields['etd']!),
        if (fields['pob'] != null && fields['pob']!.isNotEmpty) MapEntry('pob', fields['pob']!),
      ];
    } else {
      return fields.entries.where((e) => !e.key.startsWith('return') && e.value.isNotEmpty).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings Calendar'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
              view: CalendarView.month,
              dataSource: _BookingDataSource(events),
              monthViewSettings: const MonthViewSettings(
                showAgenda: true,
              ),
              onTap: (details) {
                if (details.date != null) {
                  final selectedDate = details.date!;
                  final bookingsForDay = events.where((event) =>
                    event.start.year == selectedDate.year &&
                    event.start.month == selectedDate.month &&
                    event.start.day == selectedDate.day
                  ).toList();
                  if (bookingsForDay.isNotEmpty) {
                    _showDayBookingsDialog(bookingsForDay);
                  }
                }
              },
            ),
    );
  }
}

// DataSource for SfCalendar


// Edit Booking Screen
// ...existing code...

// Edit Booking Form
class EditBookingForm extends StatelessWidget {
  final Map<String, String> booking;
  final Future<void> Function(Map<String, String>)? onSave;

  const EditBookingForm({
    super.key,
    required this.booking,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking details:', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ..._filteredBookingFields().map((e) => Text('${e.key}: ${e.value}')),
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: ElevatedButton(
                onPressed: () => onSave!(booking),
                child: const Text('Save'),
              ),
            ),
        ],
      ),
    );
  }

  // Only show relevant fields for each leg
  List<MapEntry<String, String>> _filteredBookingFields() {
    final isReturnLeg = (booking['typeOfFlight']?.toUpperCase() == 'RETURN');
    final fields = <String, String>{...booking};
    if (isReturnLeg) {
      // For return leg, show only: date, aircraft, departure, destination, eta (from etd), pob
      // Show 'eta' as the arrival at return airfield (from 'etd' field)
      return [
        if (fields['date'] != null && fields['date']!.isNotEmpty) MapEntry('date', fields['date']!),
        if (fields['aircraft'] != null && fields['aircraft']!.isNotEmpty) MapEntry('aircraft', fields['aircraft']!),
        if (fields['departure'] != null && fields['departure']!.isNotEmpty) MapEntry('departure', fields['departure']!),
        if (fields['destination'] != null && fields['destination']!.isNotEmpty) MapEntry('destination', fields['destination']!),
        if (fields['etd'] != null && fields['etd']!.isNotEmpty) MapEntry('eta', fields['etd']!),
        if (fields['pob'] != null && fields['pob']!.isNotEmpty) MapEntry('pob', fields['pob']!),
      ];
    } else {
      // For outbound leg, show all except return fields
      return fields.entries.where((e) => !e.key.startsWith('return') && e.value.isNotEmpty).toList();
    }
  }
}

class _BookingDataSource extends CalendarDataSource {
  _BookingDataSource(List<_BookingEvent> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].start;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].end;
  }

  @override
  String getSubject(int index) {
    return 'Booking';
  }

  @override
  Color getColor(int index) {
    return Colors.blueAccent;
  }

  @override
  bool isAllDay(int index) {
    return false;
  }
}

// ...existing code...



