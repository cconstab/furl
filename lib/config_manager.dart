import 'package:at_client/at_client.dart';

/// Manages filebin configuration stored in atKeys
///
/// Configuration hierarchy:
/// 1. Private override: private:filebin_override.furl@myatsign (personal config)
/// 2. Public config: public:filebin.furl@furl (or @configatsign for orgs)
/// 3. Hardcoded default: https://filebin.net
///
/// Private override atKey: private:filebin_override.furl@myatsign
/// - Value format: "url|config_atsign" e.g., "https://my-filebin.com|@mycompany"
/// - Stores both your preferred URL and which org config to check as fallback
///
/// Public config atKey: public:filebin.furl@furl (default) or public:filebin.furl@orgname
/// - Value format: Just the URL string e.g., "https://company-filebin.example.com"
/// - Published by org admins for company-wide configuration
class ConfigManager {
  static const String _defaultFilebinUrl = 'https://filebin.net';
  static const String _defaultConfigAtSign = '@furl';

  /// Get the user's private filebin override (if set)
  /// Forces remote lookup to ensure latest configuration
  static Future<Map<String, String>?> getPrivateOverride(AtClient atClient) async {
    try {
      final atKey = AtKey()
        ..key = 'filebin_override'
        ..namespace = 'furl';

      // Force remote lookup to get latest value
      final getRequestOptions = GetRequestOptions()..useRemoteAtServer = true;
      final result = await atClient.get(atKey, getRequestOptions: getRequestOptions);

      if (result.value != null && result.value.toString().isNotEmpty) {
        // Parse the stored config: url|config_atsign
        final parts = result.value.toString().split('|');
        if (parts.length >= 2) {
          return {'url': parts[0], 'config_atsign': parts[1]};
        } else if (parts.length == 1) {
          // Legacy format: just URL
          return {'url': parts[0], 'config_atsign': _defaultConfigAtSign};
        }
      }
    } catch (e) {
      // Key doesn't exist or error reading
      return null;
    }
    return null;
  }

  /// Set the user's private filebin override
  static Future<void> setPrivateOverride(AtClient atClient, String filebinUrl, String configAtSign) async {
    final atKey = AtKey()
      ..key = 'filebin_override'
      ..namespace = 'furl';

    // Store as: url|config_atsign
    final value = '$filebinUrl|$configAtSign';
    await atClient.put(atKey, value);
  }

  /// Clear the user's private filebin override
  static Future<void> clearPrivateOverride(AtClient atClient) async {
    try {
      final atKey = AtKey()
        ..key = 'filebin_override'
        ..namespace = 'furl';

      await atClient.delete(atKey);
    } catch (e) {
      // Ignore errors if key doesn't exist
    }
  }

  /// Get public filebin URL from a specific atSign
  /// Forces remote lookup to avoid stale cached values
  static Future<String?> getPublicConfig(AtClient atClient, String fromAtSign) async {
    try {
      // For public keys from another atSign, use AtKey.fromString
      // This correctly constructs: public:filebin.furl@fromAtSign
      final atKeyStr = 'public:filebin.furl$fromAtSign';
      final atKey = AtKey.fromString(atKeyStr);

      // Force remote lookup to get latest value (avoid cache staleness)
      final getRequestOptions = GetRequestOptions()..useRemoteAtServer = true;
      final result = await atClient.get(atKey, getRequestOptions: getRequestOptions);

      if (result.value != null && result.value.toString().isNotEmpty) {
        return result.value.toString();
      }
    } catch (e) {
      // Key doesn't exist or error reading - this is normal if not configured
      return null;
    }
    return null;
  }

  /// Set public filebin URL (makes it readable by everyone)
  static Future<void> setPublicConfig(AtClient atClient, String filebinUrl) async {
    final atKey = AtKey()
      ..key = 'filebin'
      ..namespace = 'furl'
      ..metadata = (Metadata()..isPublic = true);

    // Use PutRequestOptions to ensure immediate sync to remote server
    final putRequestOptions = PutRequestOptions()..useRemoteAtServer = true;
    await atClient.put(atKey, filebinUrl, putRequestOptions: putRequestOptions);

    // Brief delay to allow secondary server sync
    await Future.delayed(Duration(milliseconds: 500));
  }

  static String get defaultFilebinUrl => _defaultFilebinUrl;
  static String get defaultConfigAtSign => _defaultConfigAtSign;
}
