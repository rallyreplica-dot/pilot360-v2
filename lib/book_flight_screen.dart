import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'email_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'calendar_bookings_page.dart';
import 'package:daylight/daylight.dart' as daylight;

class BookFlightScreen extends StatefulWidget {
  final List<Map<String, String?>>? aircraftList;
  final String? homeAirfield;
  const BookFlightScreen({super.key, this.aircraftList, this.homeAirfield});

  @override
  State<BookFlightScreen> createState() => _BookFlightScreenState();
}

class _BookFlightScreenState extends State<BookFlightScreen> {
  final String baseUrl = "https://skycommand-api-1.onrender.com";
  // Helper: Send email to tower for approval using Resend API
  Future<void> _sendApprovalEmail({
    required bool outOfHours,
    required bool runwayLights,
  }) async {
    final subject = outOfHours && runwayLights
        ? 'Out of Hours & Runway Lights Request'
        : outOfHours
            ? 'Out of Hours Request'
            : 'Runway Lights Request';
    final body = StringBuffer();
    body.writeln('A booking requires approval:');
    if (outOfHours) body.writeln('- Out of hours operation requested');
    if (runwayLights) body.writeln('- Runway lights requested');
    body.writeln('');
    body.writeln('Booking Details:');
    final dateStr = _flightDate != null
      ? '${_flightDate!.toUtc().year.toString().padLeft(4, '0')}-${_flightDate!.toUtc().month.toString().padLeft(2, '0')}-${_flightDate!.toUtc().day.toString().padLeft(2, '0')}'
      : '';
    body.writeln('Date (UTC): $dateStr');
    body.writeln('Aircraft: ${_selectedAircraftReg ?? ''}');
    body.writeln('Departure: ${_departureController.text}');
    body.writeln('Destination: ${_destinationController.text}');
    body.writeln('ETD (UTC): ${_etdController.text}');
    body.writeln('ETA (UTC): ${_etaController.text}');
    body.writeln('Return ETA (UTC): ${_returnEtaController.text}');

    // TODO: Store API key securely, not in code
    const resendApiKey = 're_Adzg2wYC_8nawn5NWmiAdvCVR9GcW1vtw';

    try {
      final emailService = EmailService(apiKey: resendApiKey);
      final sent = await emailService.sendRequestEmail(
        toEmail: 'bw36320@gmail.com',
        subject: subject,
        body: body.toString(),
      );
      if (!sent) {
        _showBookingError('Could not send email. Please try again.');
      }
    } catch (e) {
      _showBookingError('Error sending email: \n' + e.toString());
    }
  }

  // Helper: Check if ETA is before ETD (for current form values)
  bool _isEtaBeforeEtd() {
    final dateStr = _flightDate != null
        ? '${_flightDate!.day.toString().padLeft(2, '0')}/${_flightDate!.month.toString().padLeft(2, '0')}/${_flightDate!.year}'
        : '';
    final etd = _combineDateTime(dateStr, _etdController.text);
    final eta = _combineDateTime(dateStr, _etaController.text);
    return etd != null && eta != null && eta.isBefore(etd);
  }

  // Helper: Parse date string (dd/mm/yyyy)
  List<int>? _parseDMY(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;
    int parseYear(String y) {
      if (y.length == 2) return 2000 + int.parse(y);
      if (y.length == 4) return int.parse(y);
      throw FormatException('Year must be 2 or 4 digits');
    }

    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = parseYear(parts[2]);
    return [day, month, year];
  }

  // Helper: Get DateTime from date string and time string
  DateTime? _combineDateTime(String dateStr, String timeStr) {
    final dmy = _parseDMY(dateStr);
    final t = _parseTime(timeStr);
    if (dmy == null || t == null) return null;
    return DateTime(dmy[2], dmy[1], dmy[0], t.hour, t.minute);
  }

  // Helper: Show error dialog
  Future<void> _showBookingError(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // State for request buttons
  bool _outOfHoursRequested = false;
  bool _runwayLightsRequested = false;

  // Helper to parse time string (HH:MM or HHMM)
  TimeOfDay? _parseTime(String value) {
    String hourStr = '', minStr = '';
    if (value.contains(":")) {
      final parts = value.split(":");
      if (parts.length != 2) return null;
      hourStr = parts[0];
      minStr = parts[1];
    } else if (value.length == 4) {
      hourStr = value.substring(0, 2);
      minStr = value.substring(2, 4);
    } else {
      return null;
    }
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minStr);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  // Check if any time is out of hours
  bool _isAnyTimeOutOfHours() {
    final etd = _parseTime(_etdController.text);
    final eta = _parseTime(_etaController.text);
    final returnEta = _parseTime(_returnEtaController.text);
    bool out = false;
    for (final t in [etd, eta, returnEta]) {
      if (t == null) continue;
      if (t.hour < _openingTime.hour ||
          (t.hour == _openingTime.hour && t.minute < _openingTime.minute)) {
        out = true;
      }
      if (t.hour > _closingTime.hour ||
          (t.hour == _closingTime.hour && t.minute > _closingTime.minute)) {
        out = true;
      }
    }
    return out;
  }

  // Check if any time is before sunrise or after sunset
  bool _isAnyTimeNeedsRunwayLights() {
    if (_sunriseTime == null || _sunsetTime == null) return false;
    final etd = _parseTime(_etdController.text);
    final eta = _parseTime(_etaController.text);
    final returnEta = _parseTime(_returnEtaController.text);
    bool needs = false;
    for (final t in [etd, eta, returnEta]) {
      if (t == null) continue;
      if (t.hour < _sunriseTime!.hour ||
          (t.hour == _sunriseTime!.hour && t.minute < _sunriseTime!.minute)) {
        needs = true;
      }
      if (t.hour > _sunsetTime!.hour ||
          (t.hour == _sunsetTime!.hour && t.minute > _sunsetTime!.minute)) {
        needs = true;
      }
    }
    return needs;
  }

  DateTime? _flightDate;
  DateTime? _returnDate;
  List<String> _airfieldNames = [];
  final List<Map<String, String>> _airfieldRecords = [];
  final TextEditingController _destinationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedAircraftReg;
  final TextEditingController _departureController = TextEditingController();
  // Define normal operating hours
  final TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _closingTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay? _sunriseTime;
  TimeOfDay? _sunsetTime;

  // London coordinates
  static const double _londonLat = 51.5074;
  static const double _londonLng = -0.1278;

  @override
  void initState() {
    super.initState();
    if (widget.homeAirfield != null && widget.homeAirfield!.isNotEmpty) {
      _departureController.text = widget.homeAirfield!;
    }
    _calculateSunriseSunset();
    _loadAirfieldNames();
    // Ensure aircraft registrations are uppercase
    if (widget.aircraftList != null) {
      for (final aircraft in widget.aircraftList!) {
        if (aircraft['registration'] != null) {
          aircraft['registration'] = aircraft['registration']!.toUpperCase();
        }
      }
    }
  }

  Future<void> _loadAirfieldNames() async {
    if (!mounted) return;
    final data = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/airports.csv');
    final rows = Csv().decode(data).toList();
    if (rows.isNotEmpty) {
      final headers = rows.first.map((e) => e.toString()).toList();
      final nameIdx = headers.indexOf('name');
      _airfieldNames = rows
          .skip(1)
          .where(
            (row) =>
                row.length > nameIdx &&
                row[nameIdx].toString().trim().isNotEmpty,
          )
          .map((row) => row[nameIdx].toString().toUpperCase())
          .toList();
      _airfieldNames.sort();
      setState(() {});
    }
  }

  Future<void> _calculateSunriseSunset() async {
    final now = DateTime.now();
    final location = daylight.DaylightLocation(_londonLat, _londonLng);
    final calc = daylight.DaylightCalculator(location);
    final result = calc.calculateForDay(now);
    final sunriseUtc = result.sunrise;
    final sunsetUtc = result.sunset;
    // Convert UTC to local time
    final sunrise = sunriseUtc?.toLocal();
    final sunset = sunsetUtc?.toLocal();
    setState(() {
      _sunriseTime = sunrise != null
          ? TimeOfDay(hour: sunrise.hour, minute: sunrise.minute)
          : null;
      _sunsetTime = sunset != null
          ? TimeOfDay(hour: sunset.hour, minute: sunset.minute)
          : null;
    });
  }

  String? _selectedTypeOfFlight;
  final TextEditingController _etdController = TextEditingController();
  final TextEditingController _etaController = TextEditingController();
  final TextEditingController _pobController = TextEditingController();
  bool _bookReturnFlight = false;
  final TextEditingController _returnEtdController = TextEditingController();
  final TextEditingController _returnEtaController = TextEditingController();
  final TextEditingController _returnPobController = TextEditingController();

  @override
  void dispose() {
    _departureController.dispose();
    _etdController.dispose();
    _etaController.dispose();
    _pobController.dispose();
    _destinationController.dispose();
    _returnEtdController.dispose();
    _returnEtaController.dispose();
    _returnPobController.dispose();
    super.dispose();
  }

  // Helper to get airfield record by name (uppercase)
  Map<String, String>? _getAirfieldRecordByName(String name) {
    return _airfieldRecords.firstWhere(
      (record) => (record['name']?.toUpperCase() ?? '') == name.toUpperCase(),
      orElse: () => {},
    );
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Build booking map
    final booking = <String, dynamic>{
      'date': _flightDate != null
          ? '${_flightDate!.day.toString().padLeft(2, '0')}/${_flightDate!.month.toString().padLeft(2, '0')}/${_flightDate!.year}'
          : '',
      'aircraft': _selectedAircraftReg ?? '',
      'departure': _departureController.text,
      'typeOfFlight': _selectedTypeOfFlight ?? '',
      'destination': _destinationController.text,
      'etd': _etdController.text,
      'eta': _etaController.text,
      'pob': _pobController.text,
      'returnDate': _returnDate != null
          ? '${_returnDate!.day.toString().padLeft(2, '0')}/${_returnDate!.month.toString().padLeft(2, '0')}/${_returnDate!.year}'
          : '',
      'returnEta': _returnEtaController.text,
      'returnPob': _returnPobController.text,
    };

    final prefs = await SharedPreferences.getInstance();
    final bookings = prefs.getStringList('flightBookings') ?? [];

    // --- VALIDATION RULES ---
    final type = (booking['typeOfFlight'] ?? '').toString().toUpperCase();
    final aircraft = booking['aircraft'] ?? '';
    final dateStr = booking['date'] ?? '';
    final etdStr = booking['etd'] ?? '';
    final etaStr = booking['eta'] ?? '';
    final etd = _combineDateTime(dateStr, etdStr);
    final eta = _combineDateTime(dateStr, etaStr);
    // 1. No double-booking for same aircraft
    for (final raw in bookings) {
      try {
        final Map<String, dynamic> b = jsonDecode(raw);
        if ((b['aircraft'] ?? '') != aircraft) continue;
        final bDate = b['date'] ?? '';
        final bEtd = _combineDateTime(bDate, b['etd'] ?? '');
        final bEta = _combineDateTime(bDate, b['eta'] ?? '');
        if (bEtd == null) continue;
        final bEnd = bEta ?? bEtd.add(const Duration(hours: 1));
        final newEnd = eta ?? etd?.add(const Duration(hours: 1));
        if (etd != null &&
            newEnd != null &&
            bEtd.isBefore(newEnd) &&
            etd.isBefore(bEnd)) {
          Navigator.of(context).pop(); // Remove loading
          await _showBookingError(
            'This aircraft is already booked during the selected time.',
          );
          return;
        }
      } catch (_) {}
    }
    // 2. Landing after take-off
    if (etd != null && eta != null && eta.isBefore(etd)) {
      Navigator.of(context).pop(); // Remove loading
      await _showBookingError('Landing time cannot be before take-off time.');
      return;
    }
    // 3. Circuit flight hourly slots
    if (type == 'CIRCUIT') {
      if (etd == null || eta == null) {
        Navigator.of(context).pop(); // Remove loading
        await _showBookingError(
          'Please enter both ETD and ETA for circuit flights.',
        );
        return;
      }
      if (etd.minute != 0 || eta.minute != 0) {
        Navigator.of(context).pop(); // Remove loading
        await _showBookingError(
          'Circuit flights must start and end exactly on the hour (e.g., 10:00–11:00).',
        );
        return;
      }
      if (eta.difference(etd).inMinutes != 60) {
        Navigator.of(context).pop(); // Remove loading
        await _showBookingError(
          'Circuit flights must be exactly 1 hour in duration (e.g., 10:00–11:00).',
        );
        return;
      }
      // 4. Circuit flight max concurrency
      int concurrent = 0;
      for (final raw in bookings) {
        try {
          final Map<String, dynamic> b = jsonDecode(raw);
          if ((b['typeOfFlight'] ?? '').toString().toUpperCase() != 'CIRCUIT') {
            continue;
          }
          final bDate = b['date'] ?? '';
          final bEtd = _combineDateTime(bDate, b['etd'] ?? '');
          final bEta = _combineDateTime(bDate, b['eta'] ?? '');
          if (bEtd == null || bEta == null) continue;
          // Check if this booking overlaps the same hour slot
          if (bEtd == etd && bEta == eta) concurrent++;
        } catch (_) {}
      }
      if (concurrent >= 3) {
        Navigator.of(context).pop(); // Remove loading
        await _showBookingError(
          'Maximum of 3 aircraft can be booked for circuits in the same hour.',
        );
        return;
      }
    }

    // For Landaway with return, add two entries: outbound and return
    if ((_selectedTypeOfFlight ?? '').toUpperCase() == 'LANDAWAY' &&
        _bookReturnFlight &&
        _returnDate != null &&
        _returnEtaController.text.isNotEmpty) {
      bookings.add(jsonEncode(booking));
      await sendBookingToAPI(booking, context: context);
      // Return leg as a separate booking (swap departure/destination, use return date/eta/pob)
      final returnBooking = Map<String, dynamic>.from(booking);
      returnBooking['date'] = booking['returnDate'];
      returnBooking['etd'] = booking['returnEta'];
      returnBooking['eta'] = '';
      returnBooking['pob'] = booking['returnPob'];
      returnBooking['departure'] = booking['destination'];
      returnBooking['destination'] = booking['departure'];
      returnBooking['typeOfFlight'] = 'RETURN';
      bookings.add(jsonEncode(returnBooking));
    } else {
      bookings.add(jsonEncode(booking));
      await sendBookingToAPI(booking, context: context);
    }

    await prefs.setStringList('flightBookings', bookings);

    Navigator.of(context).pop(); // Remove loading

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking submitted!')));
      // Navigate to bookings calendar after submission
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Let snackbar show briefly
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => CalendarBookingsPage()),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BOOK FLIGHT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Flight Date Picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _flightDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _flightDate = picked;
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'DATE OF FLIGHT',
                      hintText: 'SELECT DATE OF FLIGHT',
                    ),
                    controller: TextEditingController(
                      text: _flightDate != null
                          ? '${_flightDate!.day.toString().padLeft(2, '0')}/${_flightDate!.month.toString().padLeft(2, '0')}/${_flightDate!.year}'
                          : '',
                    ),
                    validator: (value) =>
                        _flightDate == null ? 'SELECT DATE OF FLIGHT' : null,
                    readOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedAircraftReg,
                decoration: const InputDecoration(labelText: 'AIRCRAFT'),
                items: (widget.aircraftList ?? [])
                    .map((aircraft) => aircraft['registration']?.toUpperCase())
                    .where((reg) => reg != null && reg.isNotEmpty)
                    .toSet()
                    .toList()
                    .map(
                      (reg) => DropdownMenuItem<String>(
                        value: reg,
                        child: Text(
                          reg ?? '',
                          style: const TextStyle(letterSpacing: 1.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAircraftReg = value;
                  });
                },
                validator: (value) =>
                    value == null || value.isEmpty ? 'SELECT AIRCRAFT' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departureController,
                decoration: const InputDecoration(
                  labelText: 'DEPARTURE AIRFIELD',
                ),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(letterSpacing: 1.5),
                inputFormatters: [UpperCaseTextFormatter()],
                validator: (value) => value == null || value.isEmpty
                    ? 'ENTER DEPARTURE AIRFIELD'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTypeOfFlight,
                decoration: const InputDecoration(labelText: 'TYPE OF FLIGHT'),
                items: const [
                  DropdownMenuItem(value: 'LOCAL', child: Text('LOCAL')),
                  DropdownMenuItem(value: 'CIRCUIT', child: Text('CIRCUIT')),
                  DropdownMenuItem(value: 'LANDAWAY', child: Text('LANDAWAY')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTypeOfFlight = value;
                  });
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'SELECT TYPE OF FLIGHT'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_selectedTypeOfFlight == 'LANDAWAY') ...[
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return _airfieldNames.where((String option) {
                      return option.contains(
                        textEditingValue.text.toUpperCase(),
                      );
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        controller.text = _destinationController.text;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'DESTINATION',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(letterSpacing: 1.5),
                          inputFormatters: [UpperCaseTextFormatter()],
                          onChanged: (value) {
                            _destinationController.text = value.toUpperCase();
                            controller.value = controller.value.copyWith(
                              text: value.toUpperCase(),
                              selection: TextSelection.collapsed(
                                offset: value.length,
                              ),
                            );
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'ENTER DESTINATION'
                              : null,
                        );
                      },
                  onSelected: (String selection) {
                    _destinationController.text = selection;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _etdController,
                decoration: const InputDecoration(labelText: 'ETD'),
                keyboardType: TextInputType.datetime,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(letterSpacing: 1.5),
                inputFormatters: [UpperCaseTextFormatter()],
                onChanged: (value) {
                  setState(() {});
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'ENTER ETD';
                  if (_parseTime(value) == null) {
                    return 'INVALID TIME FORMAT (HH:MM)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_selectedTypeOfFlight != 'LANDAWAY') ...[
                TextFormField(
                  controller: _etaController,
                  decoration: const InputDecoration(labelText: 'ETA'),
                  keyboardType: TextInputType.datetime,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 1.5),
                  inputFormatters: [UpperCaseTextFormatter()],
                  onChanged: (value) {
                    final upper = value.toUpperCase();
                    if (value != upper) {
                      _etaController.value = _etaController.value.copyWith(
                        text: upper,
                        selection: TextSelection.collapsed(
                          offset: upper.length,
                        ),
                      );
                    }
                    setState(() {});
                  },
                  validator: (value) {
                    if (_selectedTypeOfFlight != 'LANDAWAY' &&
                        (value == null || value.isEmpty)) {
                      return 'ENTER ETA';
                    }
                    if (value != null && value.isNotEmpty) {
                      if (_parseTime(value) == null) {
                        return 'INVALID TIME FORMAT (HH:MM)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _pobController,
                decoration: const InputDecoration(labelText: 'POB'),
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(letterSpacing: 1.5),
                inputFormatters: [UpperCaseTextFormatter()],
                validator: (value) =>
                    value == null || value.isEmpty ? 'ENTER POB' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedTypeOfFlight == 'LANDAWAY') ...[
                Row(
                  children: [
                    Checkbox(
                      value: _bookReturnFlight,
                      onChanged: (val) {
                        setState(() {
                          _bookReturnFlight = val ?? false;
                        });
                      },
                    ),
                    const Text('BOOK RETURN FLIGHT'),
                  ],
                ),
                if (_bookReturnFlight) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _returnDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _returnDate = picked;
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'RETURN DATE',
                          hintText: 'SELECT RETURN DATE',
                        ),
                        controller: TextEditingController(
                          text: _returnDate != null
                              ? '${_returnDate!.day.toString().padLeft(2, '0')}/${_returnDate!.month.toString().padLeft(2, '0')}/${_returnDate!.year}'
                              : '',
                        ),
                        validator: (value) =>
                            _returnDate == null ? 'SELECT RETURN DATE' : null,
                        readOnly: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _returnEtaController,
                    decoration: const InputDecoration(
                      labelText: 'RETURN ETA AT DESTINATION',
                    ),
                    keyboardType: TextInputType.datetime,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(letterSpacing: 1.5),
                    inputFormatters: [UpperCaseTextFormatter()],
                    onChanged: (value) {
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'ENTER RETURN ETA AT DESTINATION';
                      }
                      if (_parseTime(value) == null) {
                        return 'INVALID TIME FORMAT (HH:MM)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _returnPobController,
                    decoration: const InputDecoration(labelText: 'RETURN POB'),
                    keyboardType: TextInputType.number,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(letterSpacing: 1.5),
                    inputFormatters: [UpperCaseTextFormatter()],
                    validator: (value) => value == null || value.isEmpty
                        ? 'ENTER RETURN POB'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              if (_sunriseTime != null && _sunsetTime != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'LONDON SUNRISE: ${_sunriseTime!.format(context)}  SUNSET: ${_sunsetTime!.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!_isEtaBeforeEtd()) ...[
                if (_isAnyTimeOutOfHours())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _outOfHoursRequested
                            ? Colors.green
                            : null,
                      ),
                      onPressed: _outOfHoursRequested
                          ? null
                          : () async {
                              setState(() {
                                _outOfHoursRequested = true;
                              });
                              await _sendApprovalEmail(
                                outOfHours: true,
                                runwayLights: false,
                              );
                            },
                      child: const Text('Out of Hours Request'),
                    ),
                  ),
                if (_isAnyTimeNeedsRunwayLights())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _runwayLightsRequested
                            ? Colors.green
                            : null,
                      ),
                      onPressed: _runwayLightsRequested
                          ? null
                          : () async {
                              setState(() {
                                _runwayLightsRequested = true;
                              });
                              await _sendApprovalEmail(
                                outOfHours: false,
                                runwayLights: true,
                              );
                            },
                      child: const Text('Request Runway Lights'),
                    ),
                  ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Landing time cannot be before take-off time.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              Center(
                child: ElevatedButton(
                  onPressed: _isEtaBeforeEtd()
                      ? null
                      : () async {
                          // Require request buttons if needed
                          if (_isAnyTimeOutOfHours() && !_outOfHoursRequested) {
                            return;
                          }
                          if (_isAnyTimeNeedsRunwayLights() &&
                              !_runwayLightsRequested) {
                            return;
                          }
                          await _saveBooking();
                        },
                  child: const Text('SUBMIT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Future<void> sendBookingToAPI(Map<String, dynamic> booking, {BuildContext? context}) async {
  const baseUrl = "https://skycommand-api-1.onrender.com";

  DateTime parseDateTime(String date, String time) {
    final dateParts = date.split('/');
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    final cleanTime = time.padLeft(4, '0');
    final hour = int.parse(cleanTime.substring(0, 2));
    final minute = int.parse(cleanTime.substring(2, 4));

    return DateTime(year, month, day, hour, minute);
  }

  Future<void> trySubmit() async {
    try {
      final departure = parseDateTime(
        booking["date"],
        booking["etd"],
      );

      final arrival = (booking["eta"] != null && booking["eta"].toString().isNotEmpty)
          ? parseDateTime(booking["date"], booking["eta"])
          : departure.add(const Duration(hours: 1));

      final response = await http.post(
        Uri.parse("$baseUrl/api/flight-bookings"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "pilotId": "P001",
          "aircraftId": booking["aircraft"],
          "departureAirport": booking["departure"],
          "arrivalAirport": (booking["destination"] == null || booking["destination"].toString().trim().isEmpty)
              ? booking["departure"]
              : booking["destination"],
          "plannedDepartureTime": departure.toUtc().toIso8601String(),
          "plannedArrivalTime": arrival.toUtc().toIso8601String(),
          "passengers": int.tryParse(booking["pob"] ?? "0") ?? 0,
          "remarks": booking["typeOfFlight"] ?? "",
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit booking to server. (${response.statusCode})'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  trySubmit();
                },
              ),
            ),
          );
        }
        throw Exception('Failed to submit booking: \\${response.body}');
      }
      // Optionally, show success feedback
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking sent to server!')),
        );
      }
      print("API RESPONSE: "+response.body);
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending booking: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                trySubmit();
              },
            ),
          ),
        );
      }
      print("API ERROR: $e");
    }
  }
  await trySubmit();
}
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
