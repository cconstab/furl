import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';

class AtSignManager {
  static final AtSignLogger _logger = AtSignLogger('AtSignManager');
  static const String _atSignsKey = 'stored_atsigns';
  static const String _currentAtSignKey = 'current_atsign';

  /// Get list of all stored atSigns
  static Future<List<String>> getStoredAtSigns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final atSigns = prefs.getStringList(_atSignsKey) ?? [];
      _logger.info('Retrieved stored atSigns: $atSigns');
      return atSigns;
    } catch (e) {
      _logger.severe('Error getting stored atSigns: $e');
      return [];
    }
  }

  /// Add a new atSign to storage
  static Future<void> addAtSign(String atSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAtSigns = prefs.getStringList(_atSignsKey) ?? [];

      if (!currentAtSigns.contains(atSign)) {
        currentAtSigns.add(atSign);
        await prefs.setStringList(_atSignsKey, currentAtSigns);
        _logger.info('Added atSign: $atSign');
      }
    } catch (e) {
      _logger.severe('Error adding atSign: $e');
    }
  }

  /// Remove an atSign from storage and clean up its data
  static Future<void> removeAtSign(String atSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAtSigns = prefs.getStringList(_atSignsKey) ?? [];

      currentAtSigns.remove(atSign);
      await prefs.setStringList(_atSignsKey, currentAtSigns);

      // If this was the current atSign, clear it
      final currentAtSign = prefs.getString(_currentAtSignKey);
      if (currentAtSign == atSign) {
        await prefs.remove(_currentAtSignKey);

        // Reset AtClient if we're removing the current atSign
        try {
          AtClientManager.getInstance().reset();
          _logger.info('Reset AtClient after removing current atSign');
        } catch (e) {
          _logger.warning('Error resetting AtClient: $e');
        }
      }

      // Clean up storage for this atSign
      await _cleanUpAtSignStorage(atSign);

      _logger.info('Removed atSign: $atSign');
    } catch (e) {
      _logger.severe('Error removing atSign: $e');
    }
  }

  /// Clear all stored atSigns and their data
  static Future<void> clearAllAtSigns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final atSigns = prefs.getStringList(_atSignsKey) ?? [];

      // Clean up storage for all atSigns
      for (final atSign in atSigns) {
        await _cleanUpAtSignStorage(atSign);
      }

      // Also clear ALL keychain data to ensure clean state
      try {
        final keyChainManager = KeyChainManager.getInstance();
        final allKeychainAtSigns = await keyChainManager.getAtSignListFromKeychain();

        for (final atSign in allKeychainAtSigns) {
          try {
            await keyChainManager.deleteAtSignFromKeychain(atSign);
            _logger.info('Deleted $atSign from keychain during clearAll');

            // Also reset each atSign from keychain
            await keyChainManager.resetAtSignFromKeychain(atSign);
            _logger.info('Reset $atSign from keychain during clearAll');
          } catch (e) {
            _logger.warning('Failed to clean $atSign from keychain: $e');
          }
        }
      } catch (e) {
        _logger.warning('Error during keychain cleanup: $e');
      }

      // Clear from preferences
      await prefs.remove(_atSignsKey);
      await prefs.remove(_currentAtSignKey);

      // Clear the entire atClient storage directory to ensure clean state
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

        if (await atClientStorageDir.exists()) {
          await atClientStorageDir.delete(recursive: true);
          _logger.info('Deleted entire atClient storage directory');

          // Recreate the directory structure
          await atClientStorageDir.create(recursive: true);
          _logger.info('Recreated clean atClient storage directory');
        }
      } catch (e) {
        _logger.warning('Error clearing storage directory: $e');
      }

      // Reset AtClient completely
      try {
        AtClientManager.getInstance().reset();
        _logger.info('Reset AtClientManager completely');
      } catch (e) {
        _logger.warning('Error resetting AtClient: $e');
      }

      _logger.info('Cleared all atSigns and keychain data');
    } catch (e) {
      _logger.severe('Error clearing all atSigns: $e');
    }
  }

  /// Get the currently active atSign
  static Future<String?> getCurrentAtSign() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentAtSignKey);
    } catch (e) {
      _logger.severe('Error getting current atSign: $e');
      return null;
    }
  }

  /// Set the currently active atSign
  static Future<void> setCurrentAtSign(String atSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentAtSignKey, atSign);
      _logger.info('Set current atSign: $atSign');
    } catch (e) {
      _logger.severe('Error setting current atSign: $e');
    }
  }

  /// Clear the current atSign
  static Future<void> clearCurrentAtSign() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentAtSignKey);
      _logger.info('Cleared current atSign');
    } catch (e) {
      _logger.severe('Error clearing current atSign: $e');
    }
  }

  /// Switch to a different atSign
  static Future<bool> switchToAtSign(String atSign) async {
    try {
      _logger.info('Switching to atSign: $atSign');

      // Reset current AtClient
      AtClientManager.getInstance().reset();

      // Check if atKeys file exists for this atSign
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      // Set up AtClientPreference for the new atSign
      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'furl'
        ..hiveStoragePath = atClientStorageDir.path
        ..commitLogPath = atClientStorageDir.path
        ..isLocalStoreRequired = true;

      // Try to initialize AtClient for this atSign
      final atClientManager = AtClientManager.getInstance();
      await atClientManager.setCurrentAtSign(
        atSign,
        'furl',
        atClientPreference,
      );

      // Set as current atSign
      await setCurrentAtSign(atSign);

      _logger.info('Successfully switched to atSign: $atSign');
      return true;
    } catch (e) {
      _logger.severe('Error switching to atSign $atSign: $e');
      return false;
    }
  }

  /// Check if an atSign is already onboarded (has atKeys file)
  static Future<bool> isAtSignOnboarded(String atSign) async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final atKeysPath = '${appSupportDir.path}/atClient/${atSign}_key.atKeys';
      final atKeysFile = File(atKeysPath);
      return await atKeysFile.exists();
    } catch (e) {
      _logger.warning('Error checking if atSign is onboarded: $e');
      return false;
    }
  }

  /// Clean up storage files for a specific atSign
  static Future<void> _cleanUpAtSignStorage(String atSign) async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      _logger.info('Cleaning up storage for $atSign in: ${atClientStorageDir.path}');

      // Use the proper atPlatform KeyChainManager to delete the atSign from keychain/biometric storage
      try {
        final keyChainManager = KeyChainManager.getInstance();

        // This properly removes the atSign from both internal and shared storage
        // and cleans up all associated keys in biometric storage (keychain/keystore)
        final deleted = await keyChainManager.deleteAtSignFromKeychain(atSign);
        if (deleted) {
          _logger.info('Successfully deleted $atSign from keychain/biometric storage');
        } else {
          _logger.warning('Failed to delete $atSign from keychain/biometric storage');
        }

        // Also try the reset method for thorough cleanup
        final reset = await keyChainManager.resetAtSignFromKeychain(atSign);
        if (reset) {
          _logger.info('Successfully reset $atSign in keychain');
        } else {
          _logger.warning('Failed to reset $atSign in keychain');
        }
      } catch (e) {
        _logger.warning('Error clearing keychain/biometric storage for $atSign: $e');
      }

      // Clean up atKeys file (if it exists)
      final atKeysPath = '${atClientStorageDir.path}/${atSign}_key.atKeys';
      final atKeysFile = File(atKeysPath);
      if (await atKeysFile.exists()) {
        await atKeysFile.delete();
        _logger.info('Deleted atKeys file for: $atSign');
      } else {
        _logger.info('No atKeys file found for: $atSign at $atKeysPath');
      }

      // Clean up hive storage (if any specific to this atSign)
      final hiveDir = Directory('${atClientStorageDir.path}/hive');
      if (await hiveDir.exists()) {
        await for (final entity in hiveDir.list()) {
          if (entity.path.contains(atSign)) {
            await entity.delete(recursive: true);
            _logger.info('Deleted hive storage for: $atSign at ${entity.path}');
          }
        }
      }

      // Also clean up any commit log files for this atSign
      final commitLogPath = '${atClientStorageDir.path}/commitLog_$atSign';
      final commitLogFile = File(commitLogPath);
      if (await commitLogFile.exists()) {
        await commitLogFile.delete();
        _logger.info('Deleted commit log for: $atSign');
      }

      // Clean up any other atSign-specific directories or files
      if (await atClientStorageDir.exists()) {
        await for (final entity in atClientStorageDir.list()) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.contains(atSign.replaceAll('@', ''))) {
            try {
              await entity.delete(recursive: true);
              _logger.info('Deleted atSign-specific file/directory: ${entity.path}');
            } catch (e) {
              _logger.warning('Could not delete ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Error cleaning up storage for $atSign: $e');
    }
  }

  /// Debug method to list all storage files (useful for troubleshooting)
  static Future<void> debugListStorageFiles() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      _logger.info('=== DEBUG: Listing all storage files ===');
      _logger.info('Storage directory: ${atClientStorageDir.path}');

      if (await atClientStorageDir.exists()) {
        await for (final entity in atClientStorageDir.list(recursive: true)) {
          _logger.info('Found: ${entity.path}');
        }
      } else {
        _logger.info('Storage directory does not exist');
      }

      _logger.info('=== END DEBUG ===');
    } catch (e) {
      _logger.severe('Error listing storage files: $e');
    }
  }
}
