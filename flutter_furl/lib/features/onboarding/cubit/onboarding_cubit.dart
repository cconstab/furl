import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:path_provider/path_provider.dart';
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

// Cubit
class OnboardingCubit extends Cubit<OnboardingState> {
  static final AtSignLogger _logger = AtSignLogger('OnboardingCubit');

  OnboardingCubit() : super(OnboardingInitial()) {
    _checkExistingOnboarding();
  }

  Future<void> _checkExistingOnboarding() async {
    try {
      // Check if atClient is already initialized and user is onboarded
      final atClientManager = AtClientManager.getInstance();
      final currentAtSign = atClientManager.atClient.getCurrentAtSign();

      if (currentAtSign != null && currentAtSign.isNotEmpty) {
        _logger.info('User already onboarded with: $currentAtSign');
        emit(OnboardingCompleted(currentAtSign));
        return;
      }
    } catch (e) {
      _logger.warning('Error checking onboarding status: $e');
      // User not onboarded yet, stay in initial state
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
}
