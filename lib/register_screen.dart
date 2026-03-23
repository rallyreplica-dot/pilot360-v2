import 'package:flutter/material.dart';
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
      final lines = csvString.split('\n');
      if (lines.length < 2) return;
      final nameIdx = 3; // Column D (0-based)
      final icaoIdx = 12; // Column M (0-based)
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
      if (!mounted) return;
      setState(() {});
    }
  final AircraftDatabase aircraftDb = AircraftDatabase();
  final _formKey = GlobalKey<FormState>();
  String? userName;
  final TextEditingController nameController = TextEditingController();
  String? aircraftReg;
  String? aircraftType;
  List<Map<String, String?>> aircraftList = [];
  bool nameEntered = false;

  Future<void> setRegistrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('registrationComplete', true);
    // Optionally store userName, aircraftList, homeAirfield for later use
    if (userName != null) await prefs.setString('userName', userName!);
    await prefs.setString('homeAirfield', selectedAirfieldName ?? '');
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
              TextFormField(
                decoration: const InputDecoration(labelText: 'Aircraft Registration'),
                onSaved: (value) => aircraftReg = value,
                validator: (value) => value == null || value.isEmpty ? 'Enter registration' : null,
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
                  if (selectedAirfieldName != null) {
                    controller.text = selectedAirfieldName!;
                  }
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
                                      homeAirfield: selectedAirfieldName,
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
