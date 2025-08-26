import 'package:test/test.dart';

// Validation function matching the one in bin/furl.dart
bool validateAtSign(String atSign) {
  // Must start with @
  if (!atSign.startsWith('@')) {
    return false;
  }

  // Must have content after @
  if (atSign.length <= 1) {
    return false;
  }

  // Should only have one @
  if (atSign.indexOf('@', 1) != -1) {
    return false;
  }

  // Extract username part (after @)
  final username = atSign.substring(1);

  // Username validation: alphanumeric, dots, hyphens, underscores
  // But cannot start or end with dot, hyphen, or underscore
  final validUsernameRegex = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$',
  );

  return validUsernameRegex.hasMatch(username);
}

void main() {
  group('CLI Argument Validation Tests', () {
    test('Valid atSign formats are accepted', () {
      final validAtSigns = [
        '@alice',
        '@bob123',
        '@test_user',
        '@user-name',
        '@company.user',
      ];

      for (final atSign in validAtSigns) {
        expect(
          validateAtSign(atSign),
          isTrue,
          reason: 'Valid atSign $atSign should be accepted',
        );
      }
    });

    test('Invalid atSign formats are rejected', () {
      final invalidAtSigns = [
        'alice', // Missing @
        '@@alice', // Double @
        '@alice@bob', // Multiple @
        '@.alice', // Starts with dot
        '@alice.', // Ends with dot
        '@', // Just @
        '', // Empty string
      ];

      for (final atSign in invalidAtSigns) {
        expect(
          validateAtSign(atSign),
          isFalse,
          reason: 'Invalid atSign $atSign should be rejected',
        );
      }
    });
  });
}
