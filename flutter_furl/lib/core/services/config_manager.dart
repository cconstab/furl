import 'package:at_client_mobile/at_client_mobile.dart';

/// Manages filebin configuration stored in atKeys (Flutter version)
///
/// Same design as CLI version - uses atKeys instead of local files
class ConfigManager {
  static const String _defaultFilebinUrl = 'https://filebin.net';
  static const String _defaultConfigAtSign = '@furl';

  /// Get the user's private filebin override (if set)
  /// Forces remote lookup to ensure latest configuration
  static Future<Map<String, String>?> getPrivateOverride() async {
    try {
      final atClientManager = AtClientManager.getInstance();
      final atClient = atClientManager.atClient;

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
          return {
            'url': parts[0],
            'config_atsign': parts[1],
          };
        } else if (parts.length == 1) {
          // Legacy format: just URL
          return {
            'url': parts[0],
            'config_atsign': _defaultConfigAtSign,
          };
        }
      }
    } catch (e) {
      // Key doesn't exist or error reading
      return null;
    }
    return null;
  }

  /// Set the user's private filebin override
  static Future<void> setPrivateOverride(
    String filebinUrl,
    String configAtSign,
  ) async {
    final atClientManager = AtClientManager.getInstance();
    final atClient = atClientManager.atClient;

    final atKey = AtKey()
      ..key = 'filebin_override'
      ..namespace = 'furl';

    // Store as: url|config_atsign
    final value = '$filebinUrl|$configAtSign';
    await atClient.put(atKey, value);
  }

  /// Clear the user's private filebin override
  static Future<void> clearPrivateOverride() async {
    try {
      final atClientManager = AtClientManager.getInstance();
      final atClient = atClientManager.atClient;

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
  static Future<String?> getPublicConfig(String fromAtSign) async {
    try {
      final atClientManager = AtClientManager.getInstance();
      final atClient = atClientManager.atClient;

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

  static String get defaultFilebinUrl => _defaultFilebinUrl;
  static String get defaultConfigAtSign => _defaultConfigAtSign;
}
