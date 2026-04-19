import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_api_service.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

// Booking event model for calendar
class _BookingEvent {
  final DateTime start;
  final DateTime end;
  final String raw; // Original JSON string for editing/deleting
  final String bookingKey; // Stable key for preserving selection

  _BookingEvent({
    required this.start,
    required this.end,
    required this.raw,
    required this.bookingKey,
  });
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
  Timer? _pollingTimer;
  DateTime? _selectedDate;
  _BookingEvent? _selectedBooking;

  // Helper to generate a stable booking key from a booking map
  String _bookingKeyFromMap(Map bookingMap) {
    return [
      bookingMap['id']?.toString() ?? '',
      bookingMap['aircraftId']?.toString() ?? bookingMap['aircraft']?.toString() ?? '',
      bookingMap['pilotId']?.toString() ?? bookingMap['pilot']?.toString() ?? '',
      bookingMap['plannedDepartureTime']?.toString() ?? bookingMap['date']?.toString() ?? '',
      bookingMap['plannedArrivalTime']?.toString() ?? bookingMap['etd']?.toString() ?? '',
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    useApi = true; // Always use API mode on page open
    _loadBookingsAndPreserveSelection();
    // Start polling every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadBookingsAndPreserveSelection();
    });
  }
  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> clearAllBookings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('flightBookings');
    setState(() {
      events = [];
    });
  }

  Future<void> _loadBookingsAndPreserveSelection() async {
    print('CALENDAR: loadBookings called, useApi: ' + useApi.toString());
    final prevSelectedDate = _selectedDate;
    final prevSelectedBookingKey = _selectedBooking?.bookingKey;
    if (!mounted) return;
    setState(() => isLoading = true);
    if (useApi) {
      try {
        print('CALENDAR: About to fetch bookings from API');
        final apiBookings = await BookingApiService.fetchBookings();
        print('RAW BOOKINGS FROM API:');
        print(apiBookings);
        print('BOOKINGS COUNT: ${apiBookings.length}');
        final List<_BookingEvent> loadedEvents = [];
        int skipped = 0;
        for (final bookingMap in apiBookings) {
          try {
            print('PROCESSING BOOKING: $bookingMap');
            if (bookingMap == null || bookingMap is! Map) {
              print('CALENDAR: Skipping invalid booking entry: $bookingMap');
              skipped++;
              continue;
            }
            DateTime? start;
            DateTime? end;

            // Helper: parse DDMMYY date string
            DateTime? parseDDMMYY(String s) {
              if (s.length == 6) {
                final d = int.tryParse(s.substring(0, 2));
                final m = int.tryParse(s.substring(2, 4));
                final y = int.tryParse(s.substring(4, 6));
                if (d != null && m != null && y != null) return DateTime(2000 + y, m, d);
              }
              return null;
            }

            // Helper: parse HHMM time string into hours and minutes
            List<int>? parseHHMM(String s) {
              s = s.trim();
              if (s.isEmpty) return null;
              s = s.padLeft(4, '0');
              final h = int.tryParse(s.substring(0, 2));
              final min = int.tryParse(s.substring(2, 4));
              if (h != null && min != null) return [h, min];
              return null;
            }

            // Outbound leg
            DateTime? baseDate;
            final dateField = (bookingMap['date'] ?? '').toString();
            final pdtField = (bookingMap['plannedDepartureTime'] ?? '').toString();
            final patField = (bookingMap['plannedArrivalTime'] ?? '').toString();

            baseDate = parseDDMMYY(dateField) ?? parseDDMMYY(pdtField);

            final etdStr = (bookingMap['etd'] ?? '').toString();
            final etaStr = (bookingMap['eta'] ?? '').toString();
            final etdParts = parseHHMM(etdStr);
            final etaParts = parseHHMM(etaStr);

            if (baseDate != null && etdParts != null) {
              start = DateTime(baseDate.year, baseDate.month, baseDate.day, etdParts[0], etdParts[1]);
              if (etaParts != null) {
                end = DateTime(baseDate.year, baseDate.month, baseDate.day, etaParts[0], etaParts[1]);
              } else {
                end = start.add(const Duration(hours: 1));
              }
              print('CALENDAR: Using date+etd/eta for event: $start - $end');
            } else if (baseDate != null) {
              start = DateTime(baseDate.year, baseDate.month, baseDate.day, 9, 0);
              end = start.add(const Duration(hours: 1));
              print('CALENDAR: Using date field (no etd) for event: $start - $end');
            }

            if (start == null) {
              final isoStart = DateTime.tryParse(pdtField)?.toLocal();
              final isoEnd = DateTime.tryParse(patField)?.toLocal();
              if (isoStart != null) {
                start = isoStart;
                end = isoEnd ?? isoStart.add(const Duration(hours: 1));
                print('CALENDAR: Fallback to ISO plannedDepartureTime: $start - $end');
              }
            }
            if (start != null && end != null) {
              loadedEvents.add(_BookingEvent(
                start: start,
                end: end,
                raw: jsonEncode(bookingMap),
                bookingKey: _bookingKeyFromMap(bookingMap),
              ));
            } else {
              skipped++;
            }

            // Add return leg as a separate event if returnDate is present and different from date
            final returnDateField = (bookingMap['returnDate'] ?? '').toString();
            final returnEtdStr = (bookingMap['returnEtd'] ?? '').toString();
            final returnEtaStr = (bookingMap['returnEta'] ?? '').toString();
            if (returnDateField.isNotEmpty && returnDateField != dateField) {
              final returnBaseDate = parseDDMMYY(returnDateField);
              final returnEtdParts = parseHHMM(returnEtdStr);
              final returnEtaParts = parseHHMM(returnEtaStr);
              DateTime? returnStart;
              DateTime? returnEnd;
              if (returnBaseDate != null && returnEtdParts != null) {
                returnStart = DateTime(returnBaseDate.year, returnBaseDate.month, returnBaseDate.day, returnEtdParts[0], returnEtdParts[1]);
                if (returnEtaParts != null) {
                  returnEnd = DateTime(returnBaseDate.year, returnBaseDate.month, returnBaseDate.day, returnEtaParts[0], returnEtaParts[1]);
                } else {
                  returnEnd = returnStart.add(const Duration(hours: 1));
                }
                // Clone bookingMap and update fields for return leg
                final returnMap = Map<String, dynamic>.from(bookingMap);
                returnMap['date'] = returnDateField;
                returnMap['etd'] = returnEtdStr;
                returnMap['eta'] = returnEtaStr;
                loadedEvents.add(_BookingEvent(
                  start: returnStart,
                  end: returnEnd,
                  raw: jsonEncode(returnMap),
                  bookingKey: _bookingKeyFromMap(returnMap),
                ));
              }
            }
          } catch (err) {
            skipped++;
          }
        }
        print('EVENTS COUNT: ${loadedEvents.length}');
        print(loadedEvents);
        print('CALENDAR: Loaded ${loadedEvents.length} bookings, skipped $skipped invalid entries.');
        _BookingEvent? newSelectedBooking;
        if (prevSelectedBookingKey != null) {
          final match = loadedEvents.where((e) => e.bookingKey == prevSelectedBookingKey);
          newSelectedBooking = match.isNotEmpty ? match.first : null;
        }
        if (!mounted) return;
        setState(() {
          events = List<_BookingEvent>.from(loadedEvents);
          isLoading = false;
          _selectedDate = prevSelectedDate;
          _selectedBooking = newSelectedBooking;
        });
      } catch (e) {
        if (!mounted) return;
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
                loadedEvents.add(_BookingEvent(
                  start: start,
                  end: end,
                  raw: raw,
                  bookingKey: _bookingKeyFromMap(bookingMap),
                ));
              }
            }
          }
        } catch (_) {}
      }
      _BookingEvent? newSelectedBooking;
      if (prevSelectedBookingKey != null) {
        final match = loadedEvents.where((e) => e.bookingKey == prevSelectedBookingKey);
        newSelectedBooking = match.isNotEmpty ? match.first : null;
      }
      if (!mounted) return;
      setState(() {
        events = loadedEvents;
        isLoading = false;
        _selectedDate = prevSelectedDate;
        _selectedBooking = newSelectedBooking;
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
    if (!mounted || dayEvents.isEmpty) return;

    await showModalBottomSheet(
      context: localContext,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Compute all details once for the selected event
            _BookingEvent selectedEvent = _selectedBooking != null &&
                    dayEvents.any((e) => e.bookingKey == _selectedBooking!.bookingKey)
                ? dayEvents.firstWhere((e) => e.bookingKey == _selectedBooking!.bookingKey)
                : dayEvents.first;

            final Map<String, dynamic> bookingMap = jsonDecode(selectedEvent.raw);
            final isApi = bookingMap.containsKey('plannedDepartureTime');
            final aircraft = isApi
                ? (bookingMap['aircraftId']?.toString() ?? '')
                : (bookingMap['aircraft'] ?? 'Booking');
            final callsign = (bookingMap['callsign'] ?? '').toString();
            final pilot = isApi
                ? (bookingMap['pilotId']?.toString() ?? '')
                : (bookingMap['pilot'] ?? 'Unknown');
            final statusValue = (
              bookingMap['status'] ??
              bookingMap['bookingStatus'] ??
              bookingMap['flightStatus'] ??
              bookingMap['remarks']
            )?.toString().trim() ?? '';
            final departureTime = isApi
                ? (bookingMap['plannedDepartureTime']?.toString() ?? '')
                : (bookingMap['departureTime'] ?? '');

            final arrivalTime = isApi
                ? (bookingMap['plannedArrivalTime']?.toString() ?? '')
                : (bookingMap['arrivalTime'] ?? '');

            // If times are missing, use event start/end
            String formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            final event = dayEvents.firstWhere(
              (e) => e.bookingKey == selectedEvent.bookingKey,
              orElse: () => selectedEvent,
            );
            final depTimeDisplay = (departureTime?.isNotEmpty == true)
                ? departureTime
                : formatTime(event.start);
            final arrTimeDisplay = (arrivalTime?.isNotEmpty == true)
                ? arrivalTime
                : formatTime(event.end);

            Color statusColor = Colors.grey;
            IconData statusIcon = Icons.help_outline;
            String statusLabel = statusValue.isNotEmpty ? statusValue : 'Unknown';

            switch (statusValue.toLowerCase()) {
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
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ...existing code for details...
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Booking details:', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          if (dayEvents.length > 1) ...[
                            const Text(
                              'Bookings on this day',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 140,
                              child: ListView.builder(
                                itemCount: dayEvents.length,
                                itemBuilder: (context, index) {
                                  final item = dayEvents[index];
                                  final itemMap = jsonDecode(item.raw) as Map<String, dynamic>;
                                  final itemAircraft = itemMap['aircraftId']?.toString() ??
                                      itemMap['aircraft']?.toString() ??
                                      'Booking';
                                  final itemStatus =
                                      itemMap['status']?.toString().trim().isNotEmpty == true
                                          ? itemMap['status'].toString()
                                          : 'Unknown';
                                  final itemPilot = itemMap['pilotId']?.toString() ?? itemMap['pilot']?.toString() ?? '';
                                  String formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                  return ListTile(
                                    dense: true,
                                    selected: item.bookingKey == selectedEvent.bookingKey,
                                    title: Text(itemAircraft),
                                    subtitle: Text(
                                      '${formatTime(item.start)}-${formatTime(item.end)} • $itemStatus${itemPilot.isNotEmpty ? ' • $itemPilot' : ''}',
                                    ),
                                    onTap: () {
                                      _selectedBooking = item;
                                      setModalState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                            const Divider(),
                          ],
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
                          const SizedBox(height: 12),
                          Text('Aircraft: $aircraft'),
                          if (callsign.isNotEmpty) Text('Callsign: $callsign'),
                          if (pilot.isNotEmpty) Text('Pilot: $pilot'),
                          Text('Status: $statusLabel'),
                          Text('ETD: ${bookingMap['etd'] ?? depTimeDisplay}'),
                          Text('ETA: ${bookingMap['eta'] ?? arrTimeDisplay}'),
                          // Move Cancel Flight button here
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () async {
                                bool cancelReturn = false;
                                // Only show checkbox if this is a landaway outbound and a matching return exists
                                bool isLandaway = (bookingMap['typeOfFlight']?.toString().toUpperCase() == 'LANDAWAY');
                                String? aircraft = bookingMap['aircraft']?.toString();
                                String? destination = bookingMap['destination']?.toString();
                                String? returnDate = bookingMap['returnDate']?.toString();
                                String? returnEta = bookingMap['returnEta']?.toString();
                                // Find a matching return leg in events
                                _BookingEvent? returnEvent;
                                if (isLandaway && aircraft != null && destination != null && returnDate != null && returnEta != null) {
                                  final matches = events.where((e) {
                                    final m = jsonDecode(e.raw);
                                    return m['aircraft'] == aircraft &&
                                      m['typeOfFlight']?.toString().toUpperCase() == 'LANDAWAY' &&
                                      m['departure'] == destination &&
                                      m['date'] == returnDate &&
                                      m['eta'] == returnEta;
                                  });
                                  if (matches.isNotEmpty) {
                                    returnEvent = matches.first;
                                  } else {
                                    returnEvent = null;
                                  }
                                }
                                bool showReturnCheckbox = isLandaway && returnEvent != null;
                                bool checkboxValue = false;
                                final confirm = await showDialog<bool>(
                                  context: localContext,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setState) => AlertDialog(
                                        title: const Text('Cancel Booking'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Are you sure you want to cancel this booking?'),
                                            if (showReturnCheckbox)
                                              Row(
                                                children: [
                                                  Checkbox(
                                                    value: checkboxValue,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        checkboxValue = val ?? false;
                                                      });
                                                    },
                                                  ),
                                                  const Expanded(child: Text('Also cancel return flight?')),
                                                ],
                                              ),
                                          ],
                                        ),
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
                                  },
                                );
                                if (confirm == true) {
                                  // Try API cancel if booking has an id
                                  final bookingId = bookingMap['id']?.toString();
                                  if (bookingId != null && bookingId.isNotEmpty) {
                                    final resp = await BookingApiService.updateBookingStatus(bookingId, 'cancelled');
                                    if (resp) {
                                      // Also cancel return if requested
                                      if (showReturnCheckbox && checkboxValue && returnEvent != null) {
                                        final returnMap = jsonDecode(returnEvent.raw);
                                        final returnId = returnMap['id']?.toString();
                                        if (returnId != null && returnId.isNotEmpty) {
                                          await BookingApiService.updateBookingStatus(returnId, 'cancelled');
                                        }
                                      }
                                      if (!mounted) return;
                                      Navigator.pop(localContext);
                                      _loadBookingsAndPreserveSelection();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Booking cancelled.')),
                                      );
                                      return;
                                    }
                                  }
                                  // Fallback: local delete for non-API bookings
                                  final prefs = await SharedPreferences.getInstance();
                                  final bookings = prefs.getStringList('flightBookings') ?? [];
                                  bookings.remove(selectedEvent.raw);
                                  if (showReturnCheckbox && checkboxValue && returnEvent != null) {
                                    bookings.remove(returnEvent.raw);
                                  }
                                  await prefs.setStringList('flightBookings', bookings);
                                  if (!mounted) return;
                                  Navigator.pop(localContext);
                                  _loadBookingsAndPreserveSelection();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Booking cancelled locally.')),
                                  );
                                }
                              },
                              child: const Text('Cancel Flight'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
              _loadBookingsAndPreserveSelection();
            },
          ),
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
                  ).toList()
                    ..sort((a, b) => a.start.compareTo(b.start));

                  print('SELECTED DAY: $selectedDate');
                  print('VISIBLE EVENTS FOR DAY: ${bookingsForDay.length}');
                  print(bookingsForDay);

                  setState(() {
                    _selectedDate = selectedDate;

                    if (_selectedBooking != null &&
                        bookingsForDay.any((e) => e.bookingKey == _selectedBooking!.bookingKey)) {
                      _selectedBooking = bookingsForDay.firstWhere(
                        (e) => e.bookingKey == _selectedBooking!.bookingKey,
                      );
                    } else {
                      _selectedBooking = bookingsForDay.isNotEmpty ? bookingsForDay.first : null;
                    }
                  });

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
    // Show aircraftId for API bookings
    if (bookingMap.containsKey('plannedDepartureTime')) {
      final aircraft = bookingMap['aircraftId']?.toString() ?? '';
      return aircraft.isNotEmpty ? aircraft : 'Booking';
    }
    return 'Booking';
  }

  @override
  Color getColor(int index) {
    final _BookingEvent event = appointments![index];
    final Map<String, dynamic> bookingMap = jsonDecode(event.raw);
    if (bookingMap.containsKey('plannedDepartureTime')) {
      final status = (
        bookingMap['status'] ??
        bookingMap['bookingStatus'] ??
        bookingMap['flightStatus'] ??
        bookingMap['remarks'] ??
        ''
      ).toString().toLowerCase();
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



