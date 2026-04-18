import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'logo_widget.dart';
import 'home_screen.dart';
import 'aircraft_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
    // Airfields selection
    List<Map<String, String>> allAirfields = [];
    String? selectedAirfieldIcao;
    String? selectedAirfieldName;
    Future<void> loadAirfields() async {
      final localContext = context;
      final csvString = await DefaultAssetBundle.of(localContext).loadString('assets/airports.csv');
      final rows = Csv().decode(csvString);
      if (rows.length < 2) return;
      final headers = rows.first.map((e) => e.toString()).toList();
      final nameIdx = headers.indexOf('name');
      final icaoIdx = headers.indexOf('icao_code');
      if (nameIdx < 0 || icaoIdx < 0) return;
      allAirfields = rows.skip(1)
          .where((row) => row.length > icaoIdx && row[icaoIdx].toString().trim().isNotEmpty)
          .map((row) {
            return {
              'name': row[nameIdx].toString().trim(),
              'icao': row[icaoIdx].toString().trim(),
            };
          })
          .toList();
      if (!mounted) return;
      setState(() {});
    }
  final AircraftDatabase aircraftDb = AircraftDatabase();
  final _formKey = GlobalKey<FormState>();
  String? userName;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController callsignController = TextEditingController();
  String? aircraftReg;
  String? aircraftType;
  List<Map<String, String?>> aircraftList = [];
  bool nameEntered = false;
  bool isInstructor = false; // true = flying school instructor, false = private owner

  Future<void> setRegistrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('registrationComplete', true);
    // Optionally store userName, aircraftList, homeAirfield for later use
    if (userName != null) await prefs.setString('userName', userName!);
    await prefs.setString('companyCallsign', callsignController.text.trim());
    await prefs.setString('homeAirfield', selectedAirfieldIcao ?? selectedAirfieldName ?? '');
    await prefs.setString('homeAirfieldName', selectedAirfieldName ?? '');
    await prefs.setString('aircraftList', aircraftList.map((a) => a.toString()).join('|')); // crude serialization
  }


  Future<String?> fetchAircraftType(String reg) async {
    if (aircraftDb.regToType.isEmpty) {
      await aircraftDb.load();
    }
    return aircraftDb.getTypeForRegistration(reg);
  }

  @override
  void initState() {
    super.initState();
    aircraftDb.load();
    // Delay airfield loading until context is available
    WidgetsBinding.instance.addPostFrameCallback((_) => loadAirfields());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      backgroundColor: const Color(0xFF4FC3F7), // Slightly darker blue
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Pilot360Logo(width: 300, height: 300),
              if (!nameEntered)
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                  onSaved: (value) => userName = value,
                  validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                ),
              if (!nameEntered) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Role: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: const Text('Private Owner'),
                      selected: !isInstructor,
                      onSelected: (selected) {
                        if (selected) setState(() => isInstructor = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Instructor'),
                      selected: isInstructor,
                      onSelected: (selected) {
                        if (selected) setState(() => isInstructor = true);
                      },
                    ),
                  ],
                ),
              ],
              if (isInstructor && !nameEntered)
                TextFormField(
                  controller: callsignController,
                  decoration: const InputDecoration(
                    labelText: 'Company Callsign',
                    hintText: 'e.g. SPEEDBIRD',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: isInstructor
                      ? (value) => value == null || value.trim().isEmpty ? 'Enter your company callsign' : null
                      : null,
                ),
              if (!isInstructor)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Aircraft Registration'),
                  onSaved: (value) => aircraftReg = value,
                  validator: !isInstructor
                      ? (value) => value == null || value.isEmpty ? 'Enter registration' : null
                      : null,
                ),
              const SizedBox(height: 16),
              // Airfield single-select autocomplete
              Autocomplete<Map<String, String>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<Map<String, String>>.empty();
                  }
                  final filtered = allAirfields.where((airfield) {
                    final name = (airfield['name'] ?? '').toUpperCase();
                    final icao = (airfield['icao'] ?? '').toUpperCase();
                    final input = textEditingValue.text.toUpperCase();
                    return name.contains(input) || icao.contains(input);
                  }).toList();
                  filtered.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
                  return filtered;
                },
                displayStringForOption: (airfield) => airfield['name']?.toUpperCase() ?? '',
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Only set the text if the user selected an option
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (selectedAirfieldName != null &&
                        controller.text != selectedAirfieldName) {
                      controller.text = selectedAirfieldName!;
                    }
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Home Airfield',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Select airfield' : null,
                    onSaved: (value) {
                      // Use the selected value from onSelected
                    },
                  );
                },
                onSelected: (airfield) {
                  setState(() {
                    selectedAirfieldIcao = airfield['icao'];
                    selectedAirfieldName = airfield['name'];
                  });
                },
              ),
              const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final localContext = context;
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      if (isInstructor) {
                        // Instructor: save callsign, skip aircraft, go to home
                        if (!nameEntered) nameEntered = true;
                        await setRegistrationComplete();
                        Navigator.of(localContext).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(
                              aircraftList: [],
                              homeAirfield: selectedAirfieldIcao ?? selectedAirfieldName,
                            ),
                          ),
                        );
                        return;
                      }

                      // Private owner: aircraft registration flow
                      aircraftType = await fetchAircraftType(aircraftReg ?? '');
                      if (aircraftType == null) {
                        showDialog(
                          context: localContext,
                          builder: (context) => AlertDialog(
                            title: const Text('Aircraft Not Found'),
                            content: Text('No ICAO type found for registration: $aircraftReg'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(localContext).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      aircraftList.add({
                        'registration': aircraftReg,
                        'type': aircraftType,
                      });
                      if (!nameEntered) nameEntered = true;
                      showDialog(
                        context: localContext,
                        builder: (context) => AlertDialog(
                          title: const Text('Aircraft Registered'),
                          content: Text('Registration: $aircraftReg\nType: $aircraftType'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(localContext).pop();
                                _formKey.currentState!.reset();
                                aircraftReg = null;
                                aircraftType = null;
                                if (userName != null) {
                                  nameController.text = userName!;
                                }
                              },
                              child: const Text('Add Another'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(localContext).pop();
                                await setRegistrationComplete();
                                Navigator.of(localContext).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => HomeScreen(
                                      aircraftList: List<Map<String, String?>>.from(aircraftList),
                                      homeAirfield: selectedAirfieldIcao ?? selectedAirfieldName,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Register'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
