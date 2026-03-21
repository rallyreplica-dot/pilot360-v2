import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:convert';

class BookFlightScreenEdit extends StatefulWidget {
  final Map<String, String> booking;
  final Future<void> Function(Map<String, String> updatedBooking) onSave;
  BookFlightScreenEdit({required this.booking, required this.onSave});

  @override
  State<BookFlightScreenEdit> createState() => _BookFlightScreenEditState();
}

class _BookFlightScreenEditState extends State<BookFlightScreenEdit> {
    @override
    void dispose() {
      _etdController.dispose();
      _etaController.dispose();
      _dateController.dispose();
      _notesController.dispose();
      _returnDateController.dispose();
      _returnEtaController.dispose();
      _returnPobController.dispose();
      _pobController.dispose();
      super.dispose();
    }
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _etdController;
  late TextEditingController _etaController;
  late TextEditingController _dateController;
  late TextEditingController _notesController;
  late TextEditingController _returnDateController;
  late TextEditingController _returnEtaController;
  late TextEditingController _returnPobController;
  late TextEditingController _pobController;
  String? selectedAircraftReg;
  String? selectedDepartureName;
  String? selectedDestinationName;
  String? typeOfFlight;
  String? flightType;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _etdController = TextEditingController(text: b['etd'] ?? '');
    _etaController = TextEditingController(text: b['eta'] ?? '');
    _dateController = TextEditingController(text: b['date'] ?? '');
    _notesController = TextEditingController(text: b['notes'] ?? '');
    _returnDateController = TextEditingController(text: b['returnDate'] ?? '');
    _returnEtaController = TextEditingController(text: b['returnEta'] ?? '');
    _returnPobController = TextEditingController(text: b['returnPob'] ?? '');
    _pobController = TextEditingController(text: b['pob'] ?? '');
    selectedAircraftReg = b['aircraft'];
    selectedDepartureName = b['departure'];
    selectedDestinationName = b['destination'];
    typeOfFlight = b['typeOfFlight'];
    flightType = b['flightType'];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date (DD/MM/YY)'),
              validator: (value) => value == null || value.isEmpty ? 'Enter date' : null,
            ),
            TextFormField(
              controller: _etdController,
              decoration: const InputDecoration(labelText: 'ETD'),
              validator: (value) => value == null || value.isEmpty ? 'Enter ETD' : null,
            ),
            TextFormField(
              controller: _etaController,
              decoration: const InputDecoration(labelText: 'ETA'),
              validator: (value) => value == null || value.isEmpty ? 'Enter ETA' : null,
            ),
            TextFormField(
              controller: _pobController,
              decoration: const InputDecoration(labelText: 'POB'),
              validator: (value) => value == null || value.isEmpty ? 'Enter POB' : null,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            TextFormField(
              controller: _returnDateController,
              decoration: const InputDecoration(labelText: 'Return Date'),
            ),
            TextFormField(
              controller: _returnEtaController,
              decoration: const InputDecoration(labelText: 'Return ETA'),
            ),
            TextFormField(
              controller: _returnPobController,
              decoration: const InputDecoration(labelText: 'Return POB'),
            ),
            DropdownButtonFormField<String>(
              value: typeOfFlight,
              decoration: const InputDecoration(labelText: 'Type of Flight'),
              items: const [
                DropdownMenuItem(value: 'LOCAL', child: Text('LOCAL')),
                DropdownMenuItem(value: 'CIRCUIT', child: Text('CIRCUIT')),
                DropdownMenuItem(value: 'LANDAWAY', child: Text('LANDAWAY')),
              ],
              onChanged: (value) => setState(() => typeOfFlight = value),
            ),
            DropdownButtonFormField<String>(
              value: flightType,
              decoration: const InputDecoration(labelText: 'Flight Category'),
              items: const [
                DropdownMenuItem(value: 'TRAINING', child: Text('TRAINING')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('PRIVATE')),
              ],
              onChanged: (value) => setState(() => flightType = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final updated = Map<String, String>.from(widget.booking);
                  updated['date'] = _dateController.text;
                  updated['etd'] = _etdController.text;
                  updated['eta'] = _etaController.text;
                  updated['pob'] = _pobController.text;
                  updated['notes'] = _notesController.text;
                  updated['returnDate'] = _returnDateController.text;
                  updated['returnEta'] = _returnEtaController.text;
                  updated['returnPob'] = _returnPobController.text;
                  updated['typeOfFlight'] = typeOfFlight ?? '';
                  updated['flightType'] = flightType ?? '';
                  await widget.onSave(updated);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}


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
    events = bookings.map((raw) {
      // Parse date, etd, eta
      final dateReg = RegExp(r'date: ([^,}]+)');
      final etdReg = RegExp(r'etd: ([^,}]+)');
      final etaReg = RegExp(r'eta: ([^,}]+)');
      final dateMatch = dateReg.firstMatch(raw);
      final etdMatch = etdReg.firstMatch(raw);
      final etaMatch = etaReg.firstMatch(raw);
      DateTime start = DateTime.now();
      DateTime end = DateTime.now();
      if (dateMatch != null) {
        try {
          final parts = dateMatch.group(1)!.split('/');
          int year = 2000 + int.parse(parts[2]);
          int month = int.parse(parts[1]);
          int day = int.parse(parts[0]);
          int startHour = 0, startMinute = 0, endHour = 0, endMinute = 0;
          if (etdMatch != null) {
            final etd = etdMatch.group(1)!.trim();
            if (etd.contains(':')) {
              final etdParts = etd.split(':');
              startHour = int.tryParse(etdParts[0]) ?? 0;
              startMinute = int.tryParse(etdParts[1]) ?? 0;
            } else if (etd.length == 4) {
              startHour = int.tryParse(etd.substring(0, 2)) ?? 0;
              startMinute = int.tryParse(etd.substring(2, 4)) ?? 0;
            }
          }
          if (etaMatch != null) {
            final eta = etaMatch.group(1)!.trim();
            if (eta.contains(':')) {
              final etaParts = eta.split(':');
              endHour = int.tryParse(etaParts[0]) ?? 0;
              endMinute = int.tryParse(etaParts[1]) ?? 0;
            } else if (eta.length == 4) {
              endHour = int.tryParse(eta.substring(0, 2)) ?? 0;
              endMinute = int.tryParse(eta.substring(2, 4)) ?? 0;
            }
          }
          start = DateTime(year, month, day, startHour, startMinute);
          end = DateTime(year, month, day, endHour, endMinute);
        } catch (_) {}
      }
      return _BookingEvent(start: start, end: end, raw: raw);
    }).toList();
    setState(() => isLoading = false);
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
              onTap: (details) {
                if (details.date != null) {
                  final selectedDate = details.date!;
                  final bookingsForDay = events.where((e) =>
                    e.start.year == selectedDate.year &&
                    e.start.month == selectedDate.month &&
                    e.start.day == selectedDate.day
                  ).toList();
                  if (bookingsForDay.isNotEmpty) {
                    _showDayBookingsDialog(bookingsForDay);
                  }
                }
              },
            ),
    );
  }

  void _showDayBookingsDialog(List<_BookingEvent> dayEvents) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bookings for ${_formatDate(dayEvents.first.start)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ...dayEvents.map((event) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(event.raw),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      tooltip: 'View',
                      onPressed: () {
                        Navigator.pop(context);
                        _showBookingOptions(event, action: 'view');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.pop(context);
                        _showBookingOptions(event, action: 'edit');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete',
                      onPressed: () {
                        Navigator.pop(context);
                        _showBookingOptions(event, action: 'delete');
                      },
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showBookingOptions(_BookingEvent event, {String? action}) async {
    String? chosenAction = action;
    if (chosenAction == null) {
      chosenAction = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      );
    }
    if (chosenAction == 'view') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Booking Details'),
          content: Text(event.raw),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (chosenAction == 'delete') {
      final prefs = await SharedPreferences.getInstance();
      final bookings = prefs.getStringList('flightBookings') ?? [];
      bookings.remove(event.raw);
      await prefs.setStringList('flightBookings', bookings);
      loadBookings();
    } else if (chosenAction == 'edit') {
      Map<String, String> bookingMap = {};
      final reg = RegExp(r"(\w+): ([^,}]+)");
      for (final m in reg.allMatches(event.raw)) {
        bookingMap[m.group(1)!] = m.group(2)!.trim();
      }
      final result = await Navigator.of(context).push(
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
    }
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
  DateTime getStartTime(int index) => (appointments![index] as _BookingEvent).start;
  @override
  DateTime getEndTime(int index) => (appointments![index] as _BookingEvent).end;
  @override
  String getSubject(int index) => 'Booking';
  @override
  Color getColor(int index) => Colors.blueAccent;
}

// ...existing code for BookFlightScreenEdit and _BookFlightScreenEditState...
// ...existing code...



class _EditBookingScreen extends StatefulWidget {
  final String originalRaw;
  final Map<String, String> initialBooking;
  _EditBookingScreen({required this.originalRaw, required this.initialBooking});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Booking')),
      body: BookFlightScreenEdit(
        booking: booking,
        onSave: (updatedBooking) async {
          final prefs = await SharedPreferences.getInstance();
          final bookings = prefs.getStringList('flightBookings') ?? [];
          bookings.remove(widget.originalRaw);
          bookings.add(updatedBooking.toString());
          await prefs.setStringList('flightBookings', bookings);
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        },
      ),
    );
  }
}



// ...existing code...

