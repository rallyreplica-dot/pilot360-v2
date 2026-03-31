import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_api_service.dart';
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
  Widget build(BuildContext context) {
    print('CALENDAR: CalendarBookingsPage build called');
    return Container(); // This is just to ensure the print fires if ever called directly
  }

  @override
  State<CalendarBookingsPage> createState() => _CalendarBookingsPageState();
}

class _CalendarBookingsPageState extends State<CalendarBookingsPage> {
  // Only one initState should exist. If another exists below, remove it.
  bool isLoading = true;
  List<_BookingEvent> events = [];
  bool useApi = true; // Always use API mode by default

  @override
  void initState() {
    super.initState();
    useApi = true; // Always use API mode on page open
    loadBookings();
  }

  Future<void> clearAllBookings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('flightBookings');
    setState(() {
      events = [];
    });
  }

  Future<void> loadBookings() async {
    print('CALENDAR: loadBookings called, useApi: ' + useApi.toString());
    setState(() => isLoading = true);
    if (useApi) {
      try {
        print('CALENDAR: About to fetch bookings from API');
        final apiBookings = await BookingApiService.fetchBookings();
        print('CALENDAR: Fetched bookings from API: ' + apiBookings.toString());
        final List<_BookingEvent> loadedEvents = [];
        int skipped = 0;
        for (final bookingMap in apiBookings) {
          try {
            print('CALENDAR: Processing booking: $bookingMap');
            if (bookingMap == null || bookingMap is! Map) {
              print('CALENDAR: Skipping invalid booking entry: $bookingMap');
              skipped++;
              continue;
            }
            // Support both plannedDepartureTime/plannedArrivalTime and from/to/date fields
            DateTime? start;
            DateTime? end;
            if (bookingMap.containsKey('plannedDepartureTime') && bookingMap.containsKey('plannedArrivalTime')) {
              final dateStr = bookingMap['plannedDepartureTime'] ?? '';
              final arrivalStr = bookingMap['plannedArrivalTime'] ?? '';
              start = DateTime.tryParse(dateStr);
              end = DateTime.tryParse(arrivalStr);
              print('CALENDAR: Using plannedDepartureTime/plannedArrivalTime: $start - $end');
            } else if (bookingMap.containsKey('date') && bookingMap.containsKey('from') && bookingMap.containsKey('to')) {
              // Try to parse custom Node backend fields
              final dateStr = bookingMap['date'] ?? '';
              print('CALENDAR: Parsing Node backend date: $dateStr');
              // Try to parse as ddmmyy or yyyymmdd
              DateTime? parseDate(String s) {
                if (s.length == 6) {
                  // ddmmyy
                  final day = int.tryParse(s.substring(0,2));
                  final month = int.tryParse(s.substring(2,4));
                  final year = int.tryParse(s.substring(4,6));
                  if (day != null && month != null && year != null) {
                    return DateTime(2000+year, month, day);
                  }
                } else if (s.length == 8) {
                  // yyyymmdd
                  final year = int.tryParse(s.substring(0,4));
                  final month = int.tryParse(s.substring(4,6));
                  final day = int.tryParse(s.substring(6,8));
                  if (year != null && month != null && day != null) {
                    return DateTime(year, month, day);
                  }
                }
                return null;
              }
              final date = parseDate(dateStr);
              print('CALENDAR: Parsed date: $date');
              // Use default times if not present
              start = date?.add(const Duration(hours: 9));
              end = start?.add(const Duration(hours: 1));
              print('CALENDAR: Using default times: $start - $end');
            }
            if (start != null && end != null) {
              loadedEvents.add(_BookingEvent(
                start: start,
                end: end,
                raw: jsonEncode(bookingMap),
              ));
              print('CALENDAR: Added booking event: $start - $end');
            } else {
              print('CALENDAR: Skipping booking with invalid date/time: $bookingMap');
              skipped++;
            }
          } catch (err) {
            print('CALENDAR: Error parsing booking: $bookingMap\nError: $err');
            skipped++;
          }
        }
        print('CALENDAR: Loaded ${loadedEvents.length} bookings, skipped $skipped invalid entries.');
        setState(() {
          events = loadedEvents;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        debugPrint('CALENDAR: API fetch error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load bookings from the server. Please check your connection and try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final bookings = prefs.getStringList('flightBookings') ?? [];
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
              final end = start.add(const Duration(hours: 1));
              final isDuplicate = loadedEvents.any((e) => e.start == start && e.end == end && e.raw == raw);
              if (!isDuplicate) {
                loadedEvents.add(_BookingEvent(start: start, end: end, raw: raw));
              }
            }
          }
        } catch (_) {}
      }
      setState(() {
        events = loadedEvents;
        isLoading = false;
      });
    }
  }

  String _formatBookingTimeRange(DateTime start, DateTime end) {
    String formatTime(DateTime dt) =>
      '${dt.toUtc().hour.toString().padLeft(2, '0')}:${dt.toUtc().minute.toString().padLeft(2, '0')} UTC';
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
          final Map<String, dynamic> bookingMap = jsonDecode(event.raw);
          // Map API or local fields to user-friendly labels
          final isApi = bookingMap.containsKey('plannedDepartureTime');
          final details = <String, String>{};
          String? status;
          if (isApi) {
            // Show all available fields for API bookings
            details['Aircraft'] = bookingMap['aircraft'] ?? '';
            details['Pilot'] = bookingMap['pilot'] ?? '';
            details['Status'] = bookingMap['status'] ?? '';
            details['Departure Time'] = bookingMap['plannedDepartureTime'] ?? '';
            details['Arrival Time'] = bookingMap['plannedArrivalTime'] ?? '';
            // Add any other fields you want to show here
            status = bookingMap['status'] ?? '';
          } else {
            // Local booking
            _filteredBookingFields(Map<String, String>.from(bookingMap)).forEach((e) {
              details[e.key] = e.value;
            });
          }
          Color statusColor = Colors.grey;
          IconData statusIcon = Icons.help_outline;
          String statusLabel = '';
          if (isApi && status != null) {
            switch (status.toLowerCase()) {
              case 'submitted':
                statusColor = Colors.blue;
                statusIcon = Icons.hourglass_top;
                statusLabel = 'Submitted';
                break;
              case 'approved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_outline;
                statusLabel = 'Approved';
                break;
              case 'denied':
                statusColor = Colors.red;
                statusIcon = Icons.cancel_outlined;
                statusLabel = 'Denied';
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.help_outline;
                statusLabel = status;
            }
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking details:', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (isApi && status != null && status.isNotEmpty)
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                if (isApi && status != null && status.isNotEmpty)
                  const SizedBox(height: 12),
                ...details.entries.map((e) => Text('${e.key}: ${e.value}')),
                if (!isApi) // Only allow delete for local bookings
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
    print('AppBar actions building!');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              loadBookings();
            },
          ),
          // Hide the toggle button, always use API mode
        ],
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
    final _BookingEvent event = appointments![index];
    final Map<String, dynamic> bookingMap = jsonDecode(event.raw);
    // Show aircraft for API bookings
    if (bookingMap.containsKey('plannedDepartureTime')) {
      final aircraft = bookingMap['aircraft'] ?? '';
      return aircraft.isNotEmpty ? aircraft : 'Booking';
    }
    return 'Booking';
  }

  @override
  Color getColor(int index) {
    final _BookingEvent event = appointments![index];
    final Map<String, dynamic> bookingMap = jsonDecode(event.raw);
    if (bookingMap.containsKey('plannedDepartureTime')) {
      final status = (bookingMap['status'] ?? '').toString().toLowerCase();
      switch (status) {
        case 'submitted':
          return Colors.blue;
        case 'approved':
          return Colors.green;
        case 'denied':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }
    return Colors.blueAccent;
  }

  @override
  bool isAllDay(int index) {
    return false;
  }
}

// ...existing code...



