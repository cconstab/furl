import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';

// States
abstract class FileShareState {}

class FileShareInitial extends FileShareState {}

class FileUploading extends FileShareState {
  final double progress;

  FileUploading(this.progress);
}

class FileUploaded extends FileShareState {
  final String url;
  final String pin;

  FileUploaded({required this.url, required this.pin});
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
  FileShareCubit() : super(FileShareInitial());

  void selectFile(File file) {
    emit(FileSelected(file));
  }

  Future<void> shareFile(File file, String fileName) async {
    try {
      // First select the file, then upload and share it
      emit(FileSelected(file));
      await uploadAndShareFile(file);
    } catch (e) {
      emit(FileShareError('Failed to share file: ${e.toString()}'));
    }
  }

  Future<void> uploadAndShareFile(File file) async {
    try {
      emit(FileUploading(0.0));

      // TODO: Implement actual file encryption and upload
      // For now, simulate the process

      // Simulate upload progress
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        emit(FileUploading(i / 10.0));
      }

      // Generate unique URL and random PIN
      const uuid = Uuid();
      final fileId = uuid.v4().substring(0, 8);
      final url = 'https://furl.atsign.org/share/$fileId';
      final pin = (1000 + Random().nextInt(9000)).toString(); // 4-digit PIN

      emit(FileUploaded(url: url, pin: pin));
    } catch (e) {
      emit(FileShareError('Failed to upload file: ${e.toString()}'));
    }
  }

  void reset() {
    emit(FileShareInitial());
  }
}
