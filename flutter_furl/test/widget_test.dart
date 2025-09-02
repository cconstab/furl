// This is a basic test file to ensure flutter test runs successfully.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_furl/main.dart';

void main() {
  group('FurlApp Tests', () {
    testWidgets('App should start without crashing', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const FurlApp());

      // Verify that the app builds successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App should have a title', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const FurlApp());

      // Pump the widget to complete the build
      await tester.pump();

      // Verify that we have a MaterialApp with proper structure
      expect(find.byType(MaterialApp), findsOneWidget);

      // The app should not crash during initial load
      expect(tester.takeException(), isNull);
    });
  });

  group('Basic Unit Tests', () {
    test('Simple math test to verify test framework', () {
      expect(2 + 2, equals(4));
      expect('hello'.length, equals(5));
    });

    test('String manipulation test', () {
      const testString = 'Flutter';
      expect(testString.toLowerCase(), equals('flutter'));
      expect(testString.toUpperCase(), equals('FLUTTER'));
    });
  });
}
