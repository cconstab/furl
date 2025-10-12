import 'config_manager.dart';

/// Resolves filebin URL using atKey-based configuration (Flutter version)
class FilebinResolver {
  /// Resolves the filebin URL using atKey configuration
  /// Same resolution order as CLI version
  static Future<String> resolveFilebinUrl() async {
    // 1. Check for private override first (personal config)
    try {
      final privateConfig = await ConfigManager.getPrivateOverride();
      if (privateConfig != null && privateConfig['url'] != null) {
        final url = privateConfig['url']!;
        print('Using filebin URL from private config: $url');
        return url;
      }
    } catch (e) {
      print('Could not fetch private filebin config: $e');
    }

    // 2. Check public config from @furl or configured atSign
    try {
      // First, determine which atSign to check for public config
      final configAtSign = await getConfigAtSign();
      final publicUrl = await ConfigManager.getPublicConfig(configAtSign);
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
          print('Using furl public filebin service');
        } else {
          print('Using filebin URL from $configAtSign: $cleanUrl');
        }
        return cleanUrl;
      }
    } catch (e) {
      print('Could not fetch public filebin config: $e');
    }

    // 3. Fall back to hardcoded default
    print('Using default filebin URL: ${ConfigManager.defaultFilebinUrl}');
    return ConfigManager.defaultFilebinUrl;
  }

  /// Get configuration atSign (for looking up public filebin config)
  static Future<String> getConfigAtSign() async {
    try {
      final privateConfig = await ConfigManager.getPrivateOverride();
      if (privateConfig != null && privateConfig['config_atsign'] != null) {
        return privateConfig['config_atsign']!;
      }
    } catch (e) {
      // Ignore errors, use default
    }
    return ConfigManager.defaultConfigAtSign;
  }
}
