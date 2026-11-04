import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot360/booking_api_service.dart';

void main() {
  test('generates unique journey IDs with a Flutter Web-safe random bound', () {
    final firstJourneyId = BookingApiService.generateJourneyId();
    final secondJourneyId = BookingApiService.generateJourneyId();

    expect(firstJourneyId, matches(RegExp(r'^pilot360-\d+-[0-9a-f]+$')));
    expect(secondJourneyId, matches(RegExp(r'^pilot360-\d+-[0-9a-f]+$')));
    expect(secondJourneyId, isNot(firstJourneyId));
  });

  test(
    'Pilot360 outbound and return POST payloads carry one linked journey',
    () {
      const journeyId = 'pilot360-test-journey';
      const date = '041126';
      final outbound = BookingApiService.buildSubmissionPayload(
        booking: {
          'aircraft': 'G-TEST',
          'callsign': 'TEST1',
          'typeOfFlight': 'LANDAWAY',
          'etd': '2200',
          'eta': '2300',
          'date': date,
          'pob': '2',
          'journeyId': journeyId,
          'journeyLeg': 'outbound',
        },
        departure: 'EGSX',
        destination: 'EGSU',
        fromIcao: 'EGSX',
        toIcao: 'EGSU',
      );
      final returnFlight = BookingApiService.buildSubmissionPayload(
        booking: {
          'aircraft': 'G-TEST',
          'callsign': 'TEST1',
          'typeOfFlight': 'LANDAWAY',
          'etd': '2300',
          'eta': '0000',
          'date': '051126',
          'pob': '2',
          'journeyId': journeyId,
          'journeyLeg': 'return',
        },
        departure: 'EGSU',
        destination: 'EGSX',
        fromIcao: 'EGSU',
        toIcao: 'EGSX',
      );

      final encodedOutbound = jsonDecode(jsonEncode(outbound));
      final encodedReturn = jsonDecode(jsonEncode(returnFlight));
      expect(encodedOutbound['journeyId'], journeyId);
      expect(encodedReturn['journeyId'], journeyId);
      expect(encodedOutbound['journeyLeg'], 'outbound');
      expect(encodedReturn['journeyLeg'], 'return');
      expect(encodedOutbound['arrival'], 'EGSU');
      expect(encodedReturn['arrival'], 'EGSX');
    },
  );

  test('Pilot360 rejects a submission without stable leg identity', () {
    expect(
      () => BookingApiService.buildSubmissionPayload(
        booking: {'aircraft': 'G-TEST'},
        departure: 'EGSX',
        destination: 'EGSU',
        fromIcao: 'EGSX',
        toIcao: 'EGSU',
      ),
      throwsArgumentError,
    );
  });
}
