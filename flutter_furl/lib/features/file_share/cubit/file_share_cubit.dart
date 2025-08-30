import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:flutter_furl/core/services/file_encryption_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:io';

// States
abstract class FileShareState {}

class FileShareInitial extends FileShareState {}

class FileUploading extends FileShareState {
  final double progress;
  final String status;

  FileUploading(this.progress, {this.status = 'Uploading...'});
}

class FileUploaded extends FileShareState {
  final String url;
  final String pin;
  final String fileName;
  final int fileSize;
  final DateTime expiresAt;

  FileUploaded({
    required this.url,
    required this.pin,
    required this.fileName,
    required this.fileSize,
    required this.expiresAt,
  });
}

class FileShareError extends FileShareState {
  final String message;

  FileShareError(this.message);
}

class FileSelected extends FileShareState {
  final File file;

  FileSelected(this.file);
}

// Cubit
class FileShareCubit extends Cubit<FileShareState> {
  static final AtSignLogger _logger = AtSignLogger('FileShareCubit');

  FileShareCubit() : super(FileShareInitial());

  void selectFile(File file) {
    emit(FileSelected(file));
  }

  Future<void> shareFile(File file, String fileName) async {
    try {
      // First select the file, then upload and share it
      emit(FileSelected(file));
      await uploadAndShareFile(file, fileName);
    } catch (e) {
      _logger.severe('Error sharing file: $e');
      emit(FileShareError('Failed to share file: ${e.toString()}'));
    }
  }

  Future<void> uploadAndShareFile(File file, String fileName) async {
    try {
      emit(FileUploading(0.0, status: 'Preparing encryption...'));

      // Get current atSign
      final atClientManager = AtClientManager.getInstance();
      final currentAtSign = atClientManager.atClient.getCurrentAtSign();

      if (currentAtSign == null) {
        throw Exception('Not authenticated. Please sign in first.');
      }

      // Generate encryption keys (matching CLI exactly)
      final chaCha20Key = encrypt.Key.fromSecureRandom(32); // 32-byte key for ChaCha20
      final chaCha20Nonce = encrypt.IV.fromSecureRandom(8); // 8-byte nonce for ChaCha20
      final pin = FileEncryptionService.generateStrongPin(9);

      emit(FileUploading(0.1, status: 'Encrypting file...'));

      // Encrypt file
      final encryptedBytes = await FileEncryptionService.encryptFileChaCha20(
        file,
        chaCha20Key.bytes,
        chaCha20Nonce.bytes,
      );

      emit(FileUploading(0.4, status: 'Calculating file hash...'));

      // Calculate file hash
      final sha512Hash = await FileEncryptionService.calculateFileSha512(file);
      final fileSize = await file.length();

      emit(FileUploading(0.5, status: 'Uploading to server...'));

      // Upload to server
      final fileUrl = await FileEncryptionService.uploadFileToServer(encryptedBytes, fileName, (progress) {
        emit(FileUploading(0.5 + (progress * 0.3), status: 'Uploading to server...'));
      });

      emit(FileUploading(0.8, status: 'Storing metadata...'));

      // Store metadata in atPlatform
      final atKeyName = await FileEncryptionService.storeMetadataInAtPlatform(
        fileUrl: fileUrl,
        fileName: fileName,
        pin: pin,
        chaCha20Key: chaCha20Key.bytes,
        chaCha20Nonce: chaCha20Nonce.bytes,
        sha512Hash: sha512Hash,
        fileSize: fileSize,
      );

      emit(FileUploading(0.9, status: 'Generating share URL...'));

      // Generate retrieval URL
      final shareUrl = FileEncryptionService.generateRetrievalUrl(atSign: currentAtSign, atKeyName: atKeyName);

      // Calculate expiration time (1 hour default)
      final expiresAt = DateTime.now().add(Duration(hours: 1));

      emit(FileUploaded(url: shareUrl, pin: pin, fileName: fileName, fileSize: fileSize, expiresAt: expiresAt));

      _logger.info('File shared successfully: $shareUrl');
    } catch (e) {
      _logger.severe('Error uploading file: $e');
      emit(FileShareError('Failed to upload file: ${e.toString()}'));
    }
  }

  void reset() {
    emit(FileShareInitial());
  }
}
