import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot360/booking_availability.dart';

DateTime? _combineDateTime(String date, String time) {
  if (date.length != 6) return null;
  final day = int.tryParse(date.substring(0, 2));
  final month = int.tryParse(date.substring(2, 4));
  final year = int.tryParse(date.substring(4, 6));
  final digits = time.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0');
  final hour = int.tryParse(digits.substring(0, 2));
  final minute = int.tryParse(digits.substring(2, 4));
  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  return DateTime(2000 + year, month, day, hour, minute);
}

bool _hasConflict(List<String> bookings, String date, String etd, String eta) {
  return hasAircraftBookingConflict(
    bookings: bookings,
    aircraft: 'G-TEST',
    departure: _combineDateTime(date, etd),
    arrival: _combineDateTime(date, eta),
    combineDateTime: _combineDateTime,
  );
}

String _booking({
  required String date,
  required String etd,
  required String eta,
  String status = 'pending',
  String departure = 'EGSX',
  String destination = 'EGSU',
}) {
  return jsonEncode({
    'aircraft': 'G-TEST',
    'date': date,
    'etd': etd,
    'eta': eta,
    'status': status,
    'departure': departure,
    'destination': destination,
  });
}

void main() {
  test('cancelling a booking permits immediate rebooking of its time slot', () {
    final cancelledOutbound = {
      'aircraft': 'G-TEST',
      'date': '041126',
      'etd': '2200',
      'eta': '2300',
      'departure': 'EGSX',
      'arrival': 'EGSU',
      'status': 'cancelled',
    };
    final localBookings = [_booking(date: '041126', etd: '2200', eta: '2300')];

    expect(_hasConflict(localBookings, '041126', '2200', '2300'), isTrue);

    final afterCancellation = removeInactiveLocalBookingCopies(localBookings, [
      cancelledOutbound,
    ]);
    expect(afterCancellation, isEmpty);
    expect(_hasConflict(afterCancellation, '041126', '2200', '2300'), isFalse);
  });

  test('canceling an outbound does not remove a separate return booking', () {
    final localBookings = [
      _booking(date: '041126', etd: '2200', eta: '2300'),
      _booking(
        date: '051126',
        etd: '2200',
        eta: '2300',
        departure: 'EGSU',
        destination: 'EGSX',
      ),
    ];

    final afterCancellation = removeLocalBookingCopies(localBookings, {
      'aircraft': 'G-TEST',
      'date': '041126',
      'etd': '2200',
      'departure': 'EGSX',
      'arrival': 'EGSU',
    });

    expect(afterCancellation, hasLength(1));
    expect(_hasConflict(afterCancellation, '041126', '2200', '2300'), isFalse);
    expect(_hasConflict(afterCancellation, '051126', '2200', '2300'), isTrue);
  });

  test('active overlapping bookings still prevent rebooking', () {
    final activeBooking = _booking(date: '041126', etd: '2130', eta: '2230');

    expect(_hasConflict([activeBooking], '041126', '2200', '2300'), isTrue);
    expect(
      _hasConflict(
        [
          _booking(
            date: '041126',
            etd: '2200',
            eta: '2300',
            status: 'cancelled',
          ),
        ],
        '041126',
        '2200',
        '2300',
      ),
      isFalse,
    );
  });
}
