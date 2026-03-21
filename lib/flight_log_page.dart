import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlightLogPage extends StatefulWidget {
  const FlightLogPage({super.key});

  @override
  State<FlightLogPage> createState() => _FlightLogPageState();
}

class _FlightLogPageState extends State<FlightLogPage> {
  List<Map<String, dynamic>> flightLogs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> logs = prefs.getStringList('flightBookings') ?? [];
    setState(() {
      flightLogs = logs.map((e) {
        // Convert string map to real map
        final map = <String, dynamic>{};
        e.replaceAll(RegExp(r'[{}]'), '').split(', ').forEach((pair) {
          final kv = pair.split(':');
          if (kv.length == 2) {
            map[kv[0]] = kv[1];
          }
        });
        return map;
      }).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Logbook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear All Logs',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete All Logs?'),
                  content: const Text('This will permanently delete all flight logs. This action cannot be undone. Are you sure you want to continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('flightBookings');
                setState(() {
                  flightLogs.clear();
                });
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : flightLogs.isEmpty
              ? const Center(child: Text('No flights logged yet.'))
              : ListView.builder(
                  itemCount: flightLogs.length,
                  itemBuilder: (context, index) {
                    final log = flightLogs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(
                          '${log['date'] ?? ''} - ${log['aircraft'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Departure: ${log['departure'] ?? ''}'),
                            Text('Destination: ${log['destination'] ?? ''}'),
                            Text('ETD: ${log['etd'] ?? ''}'),
                            Text('ETA: ${log['eta'] ?? ''}'),
                            Text('POB: ${log['pob'] ?? ''}'),
                            Text('Type: ${log['flightType'] ?? ''}'),
                            if ((log['returnDate'] ?? '').isNotEmpty) ...[
                              const Divider(),
                              Text('Return Date: ${log['returnDate'] ?? ''}'),
                              Text('Return ETA: ${log['returnEta'] ?? ''}'),
                              Text('Return POB: ${log['returnPob'] ?? ''}'),
                            ],
                            if ((log['notes'] ?? '').isNotEmpty) ...[
                              const Divider(),
                              Text('Notes: ${log['notes'] ?? ''}'),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
