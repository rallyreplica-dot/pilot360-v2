import 'package:flutter/material.dart';

import 'aircraft_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookFlightScreen extends StatefulWidget {
  final String? userName;
  final List<Map<String, String?>>? aircraftList;
  final String? homeAirfield;
  const BookFlightScreen({super.key, this.userName, this.aircraftList, this.homeAirfield});

  @override
  State<BookFlightScreen> createState() => _BookFlightScreenState();
}

class _BookFlightScreenState extends State<BookFlightScreen> {
    final TextEditingController _etdController = TextEditingController();
    final TextEditingController _etaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AircraftDatabase aircraftDb = AircraftDatabase();
  List<Map<String, String>> allAirfields = [];
  String? selectedAircraftReg;
  String? selectedAircraftType;
  String? selectedDepartureIcao;
  String? selectedDepartureName;
  String? selectedDestinationIcao;
  String? selectedDestinationName;
  String? etd;
  String? eta;
  String? pob;
  String? flightType; // PRIVATE, COMMERCIAL, etc. (legacy, not used)
  String? typeOfFlight; // LOCAL, CIRCUIT, LANDAWAY
  String? returnDate;
  String? returnEta;
  String? returnPob;
  String? notes;
  String? flightDate;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    aircraftDb.load();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadAirfields());
  }

  Future<void> loadAirfields() async {
    final csvString = await DefaultAssetBundle.of(context).loadString('assets/airports.csv');
    final lines = csvString.split('\n');
    if (lines.length < 2) return;
    final nameIdx = 3; // Column D
    final icaoIdx = 12; // Column M
    allAirfields = lines.skip(1)
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final fields = line.split(',');
          if (fields.length > icaoIdx && fields[icaoIdx].trim().isNotEmpty) {
            return {
              'name': fields[nameIdx].trim(),
              'icao': fields[icaoIdx].trim(),
            };
          }
          return null;
        })
        .whereType<Map<String, String>>()
        .toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Remove duplicate registrations
    final aircraftListRaw = widget.aircraftList ?? [];
    final seenRegs = <String>{};
    final aircraftList = aircraftListRaw.where((aircraft) {
      final reg = (aircraft['registration'] ?? '').toUpperCase();
      if (seenRegs.contains(reg)) return false;
      seenRegs.add(reg);
      return true;
    }).toList();
    // Ensure selectedAircraftReg is valid (always uppercase)
    if (selectedAircraftReg != null &&
        !aircraftList.any((a) => (a['registration'] ?? '').toUpperCase() == selectedAircraftReg)) {
      selectedAircraftReg = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Flight'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Aircraft selection
              DropdownButtonFormField<String>(
                value: selectedAircraftReg,
                decoration: const InputDecoration(labelText: 'Aircraft'),
                items: aircraftList.map<DropdownMenuItem<String>>((aircraft) {
                  final reg = (aircraft['registration'] ?? '').toUpperCase();
                  final type = (aircraft['type'] ?? '').toUpperCase();
                  return DropdownMenuItem<String>(
                    value: reg,
                    child: Text('$reg ($type)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAircraftReg = value;
                    selectedAircraftType = aircraftDb.getTypeForRegistration(value ?? '') ?? '';
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Select aircraft' : null,
              ),
              const SizedBox(height: 16),
                  // Departure airfield autocomplete
                  Autocomplete<Map<String, String>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<Map<String, String>>.empty();
                      }
                      return allAirfields.where((airfield) {
                        final name = (airfield['name'] ?? '').toUpperCase();
                        final icao = (airfield['icao'] ?? '').toUpperCase();
                        final input = textEditingValue.text.toUpperCase();
                        return name.contains(input) || icao.contains(input);
                      });
                    },
                    displayStringForOption: (airfield) => airfield['name']?.toUpperCase() ?? '',
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (selectedDepartureName != null) {
                        controller.text = selectedDepartureName!;
                      } else if (widget.homeAirfield != null && (controller.text.isEmpty || controller.text != widget.homeAirfield)) {
                        controller.text = widget.homeAirfield!;
                        selectedDepartureName = widget.homeAirfield;
                      }
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Departure Airfield',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Select departure airfield' : null,
                      );
                    },
                    onSelected: (airfield) {
                      setState(() {
                        selectedDepartureIcao = airfield['icao'];
                        selectedDepartureName = airfield['name'];
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Type of flight
                  DropdownButtonFormField<String>(
                    value: typeOfFlight,
                    decoration: const InputDecoration(labelText: 'Type of Flight'),
                    items: const [
                      DropdownMenuItem(value: 'LOCAL', child: Text('LOCAL')),
                      DropdownMenuItem(value: 'CIRCUIT', child: Text('CIRCUIT')),
                      DropdownMenuItem(value: 'LANDAWAY', child: Text('LANDAWAY')),
                    ],
                    onChanged: (value) => setState(() => typeOfFlight = value),
                    validator: (value) => value == null || value.isEmpty ? 'Select type of flight' : null,
                  ),
                  const SizedBox(height: 16),
                  // Date field
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Date (DD/MM/YY)'),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          final year2 = picked.year % 100;
                          flightDate = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${year2.toString().padLeft(2, '0')}";
                          _dateController.text = flightDate!;
                        });
                      }
                    },
                    onSaved: (value) => flightDate = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter date';
                      final regex = RegExp(r'^\d{2}/\d{2}/\d{2,4}$');
                      if (!regex.hasMatch(value)) {
                        return 'Format must be DD/MM/YY';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Destination airfield autocomplete (only for landaway)
                  if (typeOfFlight == 'LANDAWAY')
                    Autocomplete<Map<String, String>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<Map<String, String>>.empty();
                        }
                        return allAirfields.where((airfield) {
                          final name = (airfield['name'] ?? '').toUpperCase();
                          final icao = (airfield['icao'] ?? '').toUpperCase();
                          final input = textEditingValue.text.toUpperCase();
                          return name.contains(input) || icao.contains(input);
                        });
                      },
                      displayStringForOption: (airfield) => airfield['name']?.toUpperCase() ?? '',
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (selectedDestinationName != null) {
                          controller.text = selectedDestinationName!;
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Destination Airfield',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Select destination airfield' : null,
                        );
                      },
                      onSelected: (airfield) {
                        setState(() {
                          selectedDestinationIcao = airfield['icao'];
                          selectedDestinationName = airfield['name'];
                        });
                      },
                    ),
                  if (typeOfFlight == 'LANDAWAY') const SizedBox(height: 16),
                  // ETD
                  TextFormField(
                    controller: _etdController,
                    decoration: const InputDecoration(labelText: 'ETD (24h, e.g. 14:30)'),
                    keyboardType: TextInputType.datetime,
                    onSaved: (value) => etd = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter ETD';
                      final now = TimeOfDay.now();
                      String hourStr = '', minStr = '';
                      if (value.contains(':')) {
                        final parts = value.split(':');
                        if (parts.length != 2) return 'Enter ETD as HH:MM or HHMM';
                        hourStr = parts[0];
                        minStr = parts[1];
                      } else if (value.length == 4) {
                        hourStr = value.substring(0, 2);
                        minStr = value.substring(2, 4);
                      } else {
                        return 'Enter ETD as HH:MM or HHMM';
                      }
                      final hour = int.tryParse(hourStr);
                      final minute = int.tryParse(minStr);
                      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                        return 'Enter valid time (e.g. 20:00 or 2000)';
                      }
                      final etdTime = TimeOfDay(hour: hour, minute: minute);
                      // Only check if flightDate is today or not set
                      final today = DateTime.now();
                      final dateText = _dateController.text.trim();
                      bool isToday = false;
                      if (dateText == '') {
                        isToday = true;
                      } else {
                        // Accept both DD/MM/YY and DD/MM/YYYY
                        final parts = dateText.split('/');
                        if (parts.length == 3) {
                          final day = int.tryParse(parts[0]);
                          final month = int.tryParse(parts[1]);
                          var year = int.tryParse(parts[2]);
                          if (year != null && year < 100) {
                            year += 2000;
                          }
                          if (day == today.day && month == today.month && year == today.year) {
                            isToday = true;
                          }
                        }
                      }
                      if (isToday) {
                        if (etdTime.hour < now.hour || (etdTime.hour == now.hour && etdTime.minute < now.minute)) {
                          return 'ETD cannot be before current time';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // ETA
                  TextFormField(
                    controller: _etaController,
                    decoration: const InputDecoration(labelText: 'ETA (24h, e.g. 15:45)'),
                    keyboardType: TextInputType.datetime,
                    onSaved: (value) => eta = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter ETA';
                      final etdValue = _etdController.text;
                      if (etdValue.isEmpty) return null; // Only check if ETD is filled
                      String parseHour(String t) => t.contains(':') ? t.split(':')[0] : t.substring(0, 2);
                      String parseMin(String t) => t.contains(':') ? t.split(':')[1] : t.substring(t.length - 2);
                      final etaHour = int.tryParse(parseHour(value));
                      final etaMin = int.tryParse(parseMin(value));
                      final etdHour = int.tryParse(parseHour(etdValue));
                      final etdMin = int.tryParse(parseMin(etdValue));
                      if (etaHour == null || etaMin == null || etdHour == null || etdMin == null) return 'Enter ETA as HH:MM or HHMM';
                      if (etaHour < etdHour || (etaHour == etdHour && etaMin < etdMin)) {
                        return 'ETA cannot be before ETD';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // POB
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Persons On Board (POB)'),
                    keyboardType: TextInputType.number,
                    onSaved: (value) => pob = value,
                    validator: (value) => value == null || value.isEmpty ? 'Enter POB' : null,
                  ),
                  const SizedBox(height: 16),
                  // Flight category
                  DropdownButtonFormField<String>(
                    value: flightType,
                    decoration: const InputDecoration(labelText: 'Flight Category'),
                    items: const [
                      DropdownMenuItem(value: 'TRAINING', child: Text('TRAINING')),
                      DropdownMenuItem(value: 'PRIVATE', child: Text('PRIVATE')),
                    ],
                    onChanged: (value) => setState(() => flightType = value),
                    validator: (value) => value == null || value.isEmpty ? 'Select flight category' : null,
                  ),
                  const SizedBox(height: 16),
                  if (flightType == 'TRAINING')
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Notes (student/instructor, details)'),
                      maxLines: 2,
                      onSaved: (value) => notes = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter notes for training flight' : null,
                    ),
                  if (flightType == 'TRAINING') const SizedBox(height: 16),
                  // Return flight fields (only for landaway)
                  if (typeOfFlight == 'LANDAWAY') ...[
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Return Date (YYYY-MM-DD)'),
                      keyboardType: TextInputType.datetime,
                      onSaved: (value) => returnDate = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter return date' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Return ETA (24h, e.g. 18:00)'),
                      keyboardType: TextInputType.datetime,
                      onSaved: (value) => returnEta = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter return ETA' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Return POB'),
                      keyboardType: TextInputType.number,
                      onSaved: (value) => returnPob = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter return POB' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        final prefs = await SharedPreferences.getInstance();
                        final booking = {
                          'aircraft': (selectedAircraftReg ?? '').toUpperCase(),
                          'departure': selectedDepartureName ?? '',
                          'destination': selectedDestinationName ?? '',
                          'date': flightDate ?? '',
                          'etd': etd ?? '',
                          'eta': eta ?? '',
                          'pob': pob ?? '',
                          'flightType': flightType ?? '',
                          'typeOfFlight': typeOfFlight ?? '',
                          'returnDate': returnDate ?? '',
                          'returnEta': returnEta ?? '',
                          'returnPob': returnPob ?? '',
                          'notes': notes ?? '',
                        };
                        final List<String> bookings = prefs.getStringList('flightBookings') ?? [];
                        bookings.add(booking.toString());
                        await prefs.setStringList('flightBookings', bookings);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Flight Booked'),
                            content: Text('Flight booked for ${booking['aircraft']} from ${booking['departure']}${typeOfFlight == 'LANDAWAY' ? ' to ${booking['destination']}' : ''}.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text('Book Flight'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
