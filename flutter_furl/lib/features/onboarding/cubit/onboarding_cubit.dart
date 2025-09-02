import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_furl/core/services/atsign_manager.dart';
import 'dart:io';

// States
abstract class OnboardingState {}

class OnboardingInitial extends OnboardingState {}

class OnboardingInProgress extends OnboardingState {}

class OnboardingCompleted extends OnboardingState {
  final String atSign;

  OnboardingCompleted(this.atSign);
}

class OnboardingError extends OnboardingState {
  final String message;

  OnboardingError(this.message);
}

class AtSignSwitching extends OnboardingState {
  final String atSign;

  AtSignSwitching(this.atSign);
}

// Cubit
class OnboardingCubit extends Cubit<OnboardingState> {
  static final AtSignLogger _logger = AtSignLogger('OnboardingCubit');
  bool _skipExistingCheck = false;

  OnboardingCubit() : super(OnboardingInitial()) {
    _checkExistingOnboarding();
  }

  /// Initialize storage paths early during app startup
  Future<void> initializeAtClientEarly() async {
    try {
      _logger.info('Early storage initialization starting...');

      // Set up storage paths early so they're ready when needed
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      if (!await atClientStorageDir.exists()) {
        await atClientStorageDir.create(recursive: true);
      }

      _logger.info('Storage paths prepared: ${atClientStorageDir.path}');
    } catch (e) {
      _logger.warning('Early storage initialization failed (non-critical): $e');
    }
  }

  Future<void> _checkExistingOnboarding() async {
    // Skip check if we've just cleared all atSigns
    if (_skipExistingCheck) {
      _logger.info('Skipping existing onboarding check after clear');
      _skipExistingCheck = false; // Reset flag
      return;
    }

    try {
      // First check if we have a current atSign from our manager
      final currentAtSign = await AtSignManager.getCurrentAtSign();
      if (currentAtSign != null && currentAtSign.isNotEmpty) {
        // Try to switch to this atSign
        final success = await AtSignManager.switchToAtSign(currentAtSign);
        if (success) {
          _logger.info('User already onboarded with: $currentAtSign');
          emit(OnboardingCompleted(currentAtSign));
          return;
        } else {
          _logger.warning('Failed to restore session for: $currentAtSign');
          // Clear the invalid current atSign
          await AtSignManager.clearCurrentAtSign();
        }
      }

      // Try to check if user is already onboarded through AtClient
      final atClientManager = AtClientManager.getInstance();

      // Safe check for existing atClient and atSign
      String? activeAtSign;
      try {
        final atClient = atClientManager.atClient;
        activeAtSign = atClient.getCurrentAtSign();
      } catch (e) {
        // atClient might not be initialized yet or in invalid state, that's okay
        _logger.info('atClient not available or invalid state: $e');
        activeAtSign = null;
      }

      if (activeAtSign != null && activeAtSign.isNotEmpty) {
        _logger.info('Found active atSign in AtClient: $activeAtSign');
        await AtSignManager.addAtSign(activeAtSign);
        await AtSignManager.setCurrentAtSign(activeAtSign);
        emit(OnboardingCompleted(activeAtSign));
        return;
      }

      _logger.info('No existing atSign found, ready for fresh onboarding');
    } catch (e) {
      _logger.warning('Error checking onboarding status: $e');
      // User not onboarded yet or state is corrupted, stay in initial state
      // Clear any potentially corrupted state
      try {
        await AtSignManager.clearCurrentAtSign();
        AtClientManager.getInstance().reset();
      } catch (resetError) {
        _logger.warning('Error resetting state: $resetError');
      }
    }
  }

  Future<void> startOnboarding(context) async {
    emit(OnboardingInProgress());

    try {
      // Get storage paths
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      // Create directory if it doesn't exist
      if (!await atClientStorageDir.exists()) {
        await atClientStorageDir.create(recursive: true);
      }

      // Create AtClientPreference with proper storage paths
      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'furl'
        ..hiveStoragePath = atClientStorageDir.path
        ..commitLogPath = atClientStorageDir.path
        ..isLocalStoreRequired = true;

      _logger.info('Using storage path: ${atClientStorageDir.path}');

      // Start the onboarding process
      final result = await AtOnboarding.onboard(
        context: context,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          rootEnvironment: RootEnvironment.Production,
          domain: 'root.atsign.org',
        ),
      );

      if (result.status == AtOnboardingResultStatus.success) {
        final atSign = result.atsign;
        if (atSign != null) {
          _logger.info('Onboarding successful for: $atSign');

          // Save the atSign to our manager
          await AtSignManager.addAtSign(atSign);
          await AtSignManager.setCurrentAtSign(atSign);

          emit(OnboardingCompleted(atSign));
        } else {
          emit(OnboardingError('Onboarding completed but atSign is null'));
        }
      } else {
        emit(OnboardingError('Onboarding failed: ${result.message}'));
      }
    } catch (e) {
      _logger.severe('Onboarding error: $e');
      emit(OnboardingError('Onboarding failed: ${e.toString()}'));
    }
  }

  /// Add a new atSign without switching to it (keeps current atSign active)
  Future<void> addNewAtSignWithoutSwitching(context) async {
    emit(OnboardingInProgress());

    try {
      // Remember the current atSign so we can switch back to it
      final currentAtSign = await AtSignManager.getCurrentAtSign();

      // Remember all current atSigns
      final allCurrentAtSigns = await AtSignManager.getStoredAtSigns();

      _logger.info('Starting fresh onboarding. Current atSign: $currentAtSign, All atSigns: $allCurrentAtSigns');

      // Get all atSigns from keychain and temporarily clear them
      final keyChainManager = KeyChainManager.getInstance();
      final keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();

      // Temporarily clear all atSigns from biometric storage to force fresh onboarding
      for (final atSign in keychainAtSigns) {
        try {
          await keyChainManager.resetAtSignFromKeychain(atSign);
          _logger.info('Temporarily cleared $atSign from biometric storage');
        } catch (e) {
          _logger.warning('Failed to clear $atSign from biometric storage: $e');
        }
      }

      // Reset the AtClientManager to ensure clean state
      AtClientManager.getInstance().reset();

      // Get storage paths
      final appSupportDir = await getApplicationSupportDirectory();
      final atClientStorageDir = Directory('${appSupportDir.path}/atClient');

      // Create directory if it doesn't exist
      if (!await atClientStorageDir.exists()) {
        await atClientStorageDir.create(recursive: true);
      }

      // Create AtClientPreference with proper storage paths
      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'furl'
        ..hiveStoragePath = atClientStorageDir.path
        ..commitLogPath = atClientStorageDir.path
        ..isLocalStoreRequired = true;

      _logger.info('Using storage path: ${atClientStorageDir.path}');

      // Start the onboarding process with clean biometric storage
      final result = await AtOnboarding.onboard(
        context: context,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          rootEnvironment: RootEnvironment.Production,
          domain: 'root.atsign.org',
        ),
      );

      if (result.status == AtOnboardingResultStatus.success) {
        final newAtSign = result.atsign;
        if (newAtSign != null) {
          _logger.info('Onboarding successful for new atSign: $newAtSign');

          // Add the new atSign to our manager
          await AtSignManager.addAtSign(newAtSign);
          _logger.info('Added new atSign $newAtSign to AtSignManager');

          // If there was a current atSign, switch back to it
          // This will restore the biometric storage data through the normal switch process
          if (currentAtSign != null && currentAtSign.isNotEmpty) {
            final success = await AtSignManager.switchToAtSign(currentAtSign);
            if (success) {
              _logger.info('Switched back to previous atSign: $currentAtSign');
              emit(OnboardingCompleted(currentAtSign));
            } else {
              _logger.warning('Failed to switch back to previous atSign: $currentAtSign');
              // If switching back fails, stay with the new one
              await AtSignManager.setCurrentAtSign(newAtSign);
              emit(OnboardingCompleted(newAtSign));
            }
          } else {
            // No previous atSign, so make the new one current
            await AtSignManager.setCurrentAtSign(newAtSign);
            emit(OnboardingCompleted(newAtSign));
          }
        } else {
          emit(OnboardingError('Onboarding completed but atSign is null'));
        }
      } else {
        // If onboarding failed, try to restore the current atSign
        if (currentAtSign != null && currentAtSign.isNotEmpty) {
          await AtSignManager.switchToAtSign(currentAtSign);
        }

        emit(OnboardingError('Onboarding failed: ${result.message}'));
      }
    } catch (e) {
      _logger.severe('Add atSign error: $e');
      emit(OnboardingError('Failed to add atSign: ${e.toString()}'));
    }
  }

  void logout() {
    try {
      // Reset the atClient and clear stored data
      AtClientManager.getInstance().reset();
      _logger.info('User logged out successfully');
      emit(OnboardingInitial());
    } catch (e) {
      _logger.severe('Logout error: $e');
      emit(OnboardingError('Logout failed: ${e.toString()}'));
    }
  }

  /// Switch to a different atSign
  Future<void> switchAtSign(String atSign) async {
    try {
      emit(AtSignSwitching(atSign));

      final success = await AtSignManager.switchToAtSign(atSign);
      if (success) {
        _logger.info('Successfully switched to: $atSign');
        emit(OnboardingCompleted(atSign));
      } else {
        emit(OnboardingError('Failed to switch to $atSign'));
      }
    } catch (e) {
      _logger.severe('Error switching atSign: $e');
      emit(OnboardingError('Failed to switch atSign: ${e.toString()}'));
    }
  }

  /// Get list of all stored atSigns
  Future<List<String>> getStoredAtSigns() async {
    return await AtSignManager.getStoredAtSigns();
  }

  /// Remove an atSign from storage
  Future<void> removeAtSign(String atSign) async {
    try {
      await AtSignManager.removeAtSign(atSign);

      // If we removed the current atSign, go back to initial state
      final currentAtSign = await AtSignManager.getCurrentAtSign();
      if (currentAtSign == null) {
        emit(OnboardingInitial());
      }
    } catch (e) {
      _logger.severe('Error removing atSign: $e');
      emit(OnboardingError('Failed to remove atSign: ${e.toString()}'));
    }
  }

  /// Clear all stored atSigns
  Future<void> clearAllAtSigns() async {
    try {
      _logger.info('Clearing all atSigns and resetting app state...');

      // Set flag to skip existing onboarding check after clear
      _skipExistingCheck = true;

      // Clear all atSign data
      await AtSignManager.clearAllAtSigns();

      // Reset AtClient state completely
      try {
        AtClientManager.getInstance().reset();
        _logger.info('Reset AtClientManager');
      } catch (e) {
        _logger.warning('Error resetting AtClientManager: $e');
      }

      // Initialize early storage to ensure clean state
      await initializeAtClientEarly();

      // Return to initial state
      emit(OnboardingInitial());
      _logger.info('Cleared all atSigns and reset to initial state');
    } catch (e) {
      _logger.severe('Error clearing atSigns: $e');
      _skipExistingCheck = false; // Reset flag on error
      emit(OnboardingError('Failed to clear atSigns: ${e.toString()}'));
    }
  }
}
