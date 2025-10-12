import 'package:at_client/at_client.dart';
import 'config_manager.dart';

/// Resolves filebin URL using atKey-based configuration
///
/// Resolution order:
/// 1. Private override: private:filebin_override.furl@myatsign
/// 2. Public config: public:filebin.furl@<config_atsign> (default: @furl)
/// 3. Hardcoded default: https://filebin.net
class FilebinResolver {
  /// Resolves the filebin URL using atKey configuration
  static Future<String> resolveFilebinUrl(AtClient atClient) async {
    // 1. Check for private override first (personal config)
    try {
      final privateConfig = await ConfigManager.getPrivateOverride(atClient);
      if (privateConfig != null && privateConfig['url'] != null) {
        final url = privateConfig['url']!;
        print('ℹ Using filebin URL from private config: $url');
        return url;
      }
    } catch (e) {
      print('⚠ Could not fetch private filebin config: $e');
    }

    // 2. Check public config from @furl or configured atSign
    try {
      // First, determine which atSign to check for public config
      final configAtSign = await getConfigAtSign(atClient);
      final publicUrl = await ConfigManager.getPublicConfig(
        atClient,
        configAtSign,
      );
      if (publicUrl != null && publicUrl.isNotEmpty) {
        // Clean the URL: trim whitespace, remove trailing quotes and slashes
        var cleanUrl = publicUrl.trim();
        if (cleanUrl.endsWith("'") || cleanUrl.endsWith('"')) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        }
        // Remove trailing slash to avoid double slashes when constructing paths
        if (cleanUrl.endsWith('/')) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        }

        // Show friendly message for @furl public service
        if (configAtSign == ConfigManager.defaultConfigAtSign) {
          print('ℹ Using furl public filebin service');
        } else {
          print('ℹ Using filebin URL from $configAtSign: $cleanUrl');
        }
        return cleanUrl;
      }
    } catch (e) {
      print('⚠ Could not fetch public filebin config: $e');
    }

    // 3. Fall back to hardcoded default
    print('ℹ Using default filebin URL: ${ConfigManager.defaultFilebinUrl}');
    return ConfigManager.defaultFilebinUrl;
  }

  /// Get configuration atSign (for looking up public filebin config)
  /// Checks user's private override first, then defaults to @furl
  static Future<String> getConfigAtSign(AtClient atClient) async {
    try {
      final privateConfig = await ConfigManager.getPrivateOverride(atClient);
      if (privateConfig != null && privateConfig['config_atsign'] != null) {
        return privateConfig['config_atsign']!;
      }
    } catch (e) {
      // Ignore errors, use default
    }
    return ConfigManager.defaultConfigAtSign;
  }
}
