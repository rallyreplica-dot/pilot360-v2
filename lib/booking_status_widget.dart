import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingStatusWidget extends StatefulWidget {
  final int bookingId;
  const BookingStatusWidget({super.key, required this.bookingId});

  @override
  State<BookingStatusWidget> createState() => _BookingStatusWidgetState();
}

class _BookingStatusWidgetState extends State<BookingStatusWidget> {
  String? status;
  String? flightTime;
  String? error;
  bool loading = false;

  Future<void> fetchStatus() async {
    setState(() {
      loading = true;
      error = null;
    });
    final url = Uri.parse('http://192.168.178.40:5000/bookings');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List bookings = jsonDecode(response.body);
        final booking = bookings.firstWhere(
          (b) => b['id'] == widget.bookingId,
          orElse: () => null,
        );
        if (booking != null) {
          setState(() {
            status = booking['status'];
            flightTime = '${booking['date']} ${booking['time']}';
            loading = false;
          });
        } else {
          setState(() {
            error = 'Booking not found.';
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Failed to fetch. Status: ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Booking ID: ${widget.bookingId}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : fetchStatus,
              child: Text(loading ? 'Checking...' : 'Check Booking Status'),
            ),
            SizedBox(height: 16),
            if (status != null) ...[
              Text('Status: $status', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('Flight Time: $flightTime'),
            ],
            if (error != null) ...[
              Text(error!, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
