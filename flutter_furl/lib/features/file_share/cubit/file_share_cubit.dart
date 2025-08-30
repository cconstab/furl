import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';

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

      // Simulate successful upload with dummy URL and PIN
      const dummyUrl = 'https://furl.atsign.org/share/abc123';
      const dummyPin = '1234';

      emit(FileUploaded(url: dummyUrl, pin: dummyPin));
    } catch (e) {
      emit(FileShareError('Failed to upload file: ${e.toString()}'));
    }
  }

  void reset() {
    emit(FileShareInitial());
  }
}
