
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';


class CalendarBookingsPage extends StatefulWidget {
  const CalendarBookingsPage({super.key});

  @override
  State<CalendarBookingsPage> createState() => _CalendarBookingsPageState();
}

class _CalendarBookingsPageState extends State<CalendarBookingsPage> {
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
      // Parse booking string to map
      final reg = RegExp(r"(\w+): ([^,}]+)");
      Map<String, String> bookingMap = {};
      for (final m in reg.allMatches(raw)) {
        bookingMap[m.group(1)!] = m.group(2)!.trim();
      }
      // Parse date/time for start/end
      try {
        final dateStr = bookingMap['date'] ?? '';
        final etdStr = bookingMap['etd'] ?? '';
        final etaStr = bookingMap['eta'] ?? '';
        if (dateStr.isNotEmpty && etdStr.isNotEmpty && etaStr.isNotEmpty) {
          final parts = dateStr.split('/');
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = 2000 + int.parse(parts[2]);
          final etdParts = etdStr.split(':');
          final etaParts = etaStr.split(':');
          final start = DateTime(year, month, day, int.parse(etdParts[0]), etdParts.length > 1 ? int.parse(etdParts[1]) : 0);
          final end = DateTime(year, month, day, int.parse(etaParts[0]), etaParts.length > 1 ? int.parse(etaParts[1]) : 0);
          loadedEvents.add(_BookingEvent(start: start, end: end, raw: raw));
        }
        // Add return leg as separate event if present
        final returnDateStr = bookingMap['returnDate'] ?? '';
        final returnEtaStr = bookingMap['returnEta'] ?? '';
        if (returnDateStr.isNotEmpty && returnEtaStr.isNotEmpty) {
          final parts = returnDateStr.split('/');
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = 2000 + int.parse(parts[2]);
          final etaParts = returnEtaStr.split(':');
          final start = DateTime(year, month, day, int.parse(etaParts[0]), etaParts.length > 1 ? int.parse(etaParts[1]) : 0);
          final end = start.add(const Duration(minutes: 30));
          loadedEvents.add(_BookingEvent(start: start, end: end, raw: raw));
        }
      } catch (_) {}
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
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final event in dayEvents)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: const Text(
                    'Booking',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _formatBookingTimeRange(event.start, event.end),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  tileColor: Colors.blueAccent,
                  onTap: () async {
                    final localContext2 = localContext;
                    if (!mounted) return;
                    Navigator.pop(localContext2); // Close the dialog
                    // Parse booking map from event.raw
                    Map<String, String> bookingMap = {};
                    final reg = RegExp(r"(\w+): ([^,}]+)");
                    for (final m in reg.allMatches(event.raw)) {
                      bookingMap[m.group(1)!] = m.group(2)!.trim();
                    }
                    final result = await Navigator.of(localContext2).push(
                      MaterialPageRoute(
                        builder: (context) => _EditBookingScreen(
                          originalRaw: event.raw,
                          initialBooking: bookingMap,
                        ),
                      ),
                    );
                    if (result == true) {
                      loadBookings();
                    }
                  },
                  trailing: Builder(
                    builder: (context) {
                      // Only allow deleting the outbound event if it is not a return leg
                      Map<String, String> bookingMap = {};
                      final reg = RegExp(r"(\w+): ([^,}]+)");
                      for (final m in reg.allMatches(event.raw)) {
                        bookingMap[m.group(1)!] = m.group(2)!.trim();
                      }
                      final isReturnLeg =
                          bookingMap['returnDate'] != null &&
                          bookingMap['returnDate']!.isNotEmpty &&
                          event.start.day.toString().padLeft(2, '0') ==
                              bookingMap['returnDate']!.split('/')[0] &&
                          event.start.month.toString().padLeft(2, '0') ==
                              bookingMap['returnDate']!.split('/')[1];
                      // Only allow delete for outbound if not a return leg, and for return leg only allow delete if it is the return event
                      return IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        tooltip: isReturnLeg
                            ? 'Cancel Return Flight'
                            : 'Cancel Booking',
                        onPressed: () async {
                          final localContext3 = localContext;
                          if (!isReturnLeg) {
                            // Outbound: normal delete
                            final confirm = await showDialog<bool>(
                              context: localContext3,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Booking'),
                                content: const Text(
                                  'Are you sure you want to cancel this booking?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(localContext3).pop(false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(localContext3).pop(true),
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
                              Navigator.pop(localContext3); // Close the dialog
                              loadBookings();
                            }
                          } else {
                            // Return leg: do not allow deleting the outbound, only allow removing the return leg fields
                            final confirm = await showDialog<bool>(
                              context: localContext3,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Return Flight'),
                                content: const Text(
                                  'Are you sure you want to cancel just the return leg? The outbound booking will remain.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(localContext3).pop(false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(localContext3).pop(true),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final prefs = await SharedPreferences.getInstance();
                              final bookings = prefs.getStringList('flightBookings') ?? [];
                              // Remove only the return leg fields from the booking string
                              // Parse the booking string to a map, clear return fields, and update
                              Map<String, String> map = {};
                              for (final m in reg.allMatches(event.raw)) {
                                map[m.group(1)!] = m.group(2)!.trim();
                              }
                              map['returnDate'] = '';
                              map['returnEta'] = '';
                              map['returnPob'] = '';
                              map['returnDeparture'] = '';
                              // Rebuild the booking string
                              final newRaw = map.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', ');
                              final idx = bookings.indexOf(event.raw);
                              if (idx != -1) {
                                bookings[idx] = newRaw;
                                await prefs.setStringList('flightBookings', bookings);
                              }
                              if (!mounted) return;
                              Navigator.pop(localContext3); // Close the dialog
                              loadBookings();
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings Calendar')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
              view: CalendarView.month,
              dataSource: _BookingDataSource(events),
              monthViewSettings: const MonthViewSettings(
                showAgenda: true,
                agendaItemHeight: 50,
                appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
              ),
              timeSlotViewSettings: const TimeSlotViewSettings(
                timeFormat: 'HH:mm',
              ),
              onTap: (details) {
                if (details.date != null) {
                  final selectedDate = details.date!;
                  final bookingsForDay = events
                      .where(
                        (e) =>
                            e.start.year == selectedDate.year &&
                            e.start.month == selectedDate.month &&
                            e.start.day == selectedDate.day,
                      )
                      .toList();
                  if (bookingsForDay.isNotEmpty) {
                    _showDayBookingsDialog(bookingsForDay);
                  }
                }
              },
            ),
    );
  }
}

class _BookingEvent {
  final DateTime start;
  final DateTime end;
  final String raw;

  _BookingEvent({required this.start, required this.end, required this.raw});
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

class _EditBookingScreen extends StatefulWidget {
  final String originalRaw;
  final Map<String, String> initialBooking;

  const _EditBookingScreen({
    required this.originalRaw,
    required this.initialBooking,
  });

  @override
  State<_EditBookingScreen> createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<_EditBookingScreen> {
  late Map<String, String> booking;

  @override
  void initState() {
    super.initState();
    booking = Map<String, String>.from(widget.initialBooking);
  }

  @override
  Widget build(BuildContext context) {
    final localContext = context;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Booking')),
      body: EditBookingForm(
        booking: booking,
        onSave: (updatedBooking) async {
          final prefs = await SharedPreferences.getInstance();
          final bookings = prefs.getStringList('flightBookings') ?? [];
          bookings.remove(widget.originalRaw);
          bookings.add(updatedBooking.toString());
          await prefs.setStringList('flightBookings', bookings);
          if (!mounted) return;
          Navigator.of(localContext).pop(true);
        },
      ),
    );
  }
}

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
    // Minimal placeholder UI for now
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking details:', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...booking.entries.map((e) => Text('${e.key}: ${e.value}')),
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
}



