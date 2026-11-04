import 'dart:convert';

const _inactiveBookingStatuses = {'cancelled', 'canceled', 'denied', 'completed'};

bool hasAircraftBookingConflict({
  required Iterable<String> bookings,
  required String aircraft,
  required DateTime? departure,
  required DateTime? arrival,
  required DateTime? Function(String date, String time) combineDateTime,
}) {
  if (departure == null) return false;
  final normalizedAircraft = aircraft.trim().toUpperCase();
  final newEnd = arrival ?? departure.add(const Duration(hours: 1));

  for (final raw in bookings) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final booking = Map<String, dynamic>.from(decoded);
      final status = (booking['status'] ?? '').toString().trim().toLowerCase();
      if (_inactiveBookingStatuses.contains(status)) continue;
      if ((booking['aircraft'] ?? '').toString().trim().toUpperCase() !=
          normalizedAircraft) {
        continue;
      }

      final date = (booking['date'] ?? '').toString();
      final start = combineDateTime(date, (booking['etd'] ?? '').toString());
      if (start == null) continue;
      final end = combineDateTime(date, (booking['eta'] ?? '').toString()) ??
          start.add(const Duration(hours: 1));
      if (start.isBefore(newEnd) && departure.isBefore(end)) return true;
    } catch (_) {
      continue;
    }
  }
  return false;
}

List<String> removeLocalBookingCopies(
  Iterable<String> bookings,
  Map bookingToRemove,
) {
  final aircraft = _normalizedValue(bookingToRemove['aircraft']);
  final date = _normalizedValue(bookingToRemove['date']);
  final etd = _normalizedTime(bookingToRemove['etd']);
  if (aircraft.isEmpty || date.isEmpty || etd.isEmpty) {
    return bookings.toList();
  }

  final departure = _normalizedValue(
    bookingToRemove['departure'] ?? bookingToRemove['from'],
  );
  final destination = _normalizedValue(
    bookingToRemove['destination'] ??
        bookingToRemove['arrival'] ??
        bookingToRemove['to'],
  );

  return bookings.where((raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      final booking = Map<String, dynamic>.from(decoded);
      final matchesFlight = _normalizedValue(booking['aircraft']) == aircraft &&
          _normalizedValue(booking['date']) == date &&
          _normalizedTime(booking['etd']) == etd;
      if (!matchesFlight) return true;

      final localDeparture = _normalizedValue(
        booking['departure'] ?? booking['from'],
      );
      final localDestination = _normalizedValue(
        booking['destination'] ?? booking['arrival'] ?? booking['to'],
      );
      final departureMatches =
          departure.isEmpty || localDeparture.isEmpty || localDeparture == departure;
      final destinationMatches = destination.isEmpty ||
          localDestination.isEmpty ||
          localDestination == destination;
      return !(departureMatches && destinationMatches);
    } catch (_) {
      return true;
    }
  }).toList();
}

List<String> removeInactiveLocalBookingCopies(
  Iterable<String> localBookings,
  Iterable<Map<String, dynamic>> serverBookings,
) {
  var remaining = localBookings.toList();
  for (final booking in serverBookings) {
    final status = (booking['status'] ?? '').toString().trim().toLowerCase();
    if (_inactiveBookingStatuses.contains(status)) {
      remaining = removeLocalBookingCopies(remaining, booking);
    }
  }
  return remaining;
}

String _normalizedValue(Object? value) =>
    (value ?? '').toString().trim().toUpperCase();

String _normalizedTime(Object? value) =>
    (value ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0');
