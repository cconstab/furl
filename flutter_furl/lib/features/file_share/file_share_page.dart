import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_furl/features/file_share/cubit/file_share_cubit.dart';
import 'package:flutter_furl/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'dart:math';

class FileSharePage extends StatelessWidget {
  const FileSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // Purple blue
              Color(0xFF764ba2), // Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text('🔐', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Furl - Secure File Sharing',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    BlocBuilder<OnboardingCubit, OnboardingState>(
                      builder: (context, state) {
                        if (state is OnboardingCompleted) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              state.atSign,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'logout') {
                          context.read<OnboardingCubit>().logout();
                          context.read<FileShareCubit>().reset();
                        } else if (value == 'settings') {
                          _showSettingsDialog(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, size: 18),
                              SizedBox(width: 8),
                              Text('Settings'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18),
                              SizedBox(width: 8),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main content in white container
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: BlocConsumer<FileShareCubit, FileShareState>(
                    listener: (context, state) {
                      if (state is FileShareError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Text('❌', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(state.message)),
                              ],
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Instructions
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFe3f2fd), Color(0xFFf3e5f5)]),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFb3d9ff)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to Share Files:',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: const Color(0xFF1976d2),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('📁 1. Drag and drop a file or click to select'),
                                  const SizedBox(height: 4),
                                  const Text('🔐 2. Your file will be encrypted automatically'),
                                  const SizedBox(height: 4),
                                  const Text('🔗 3. Share the generated URL and PIN'),
                                  const SizedBox(height: 4),
                                  const Text('🔑 4. Recipients use the PIN to decrypt the file'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // File Drop Zone
                            _buildDropZone(context, state),

                            const SizedBox(height: 30),

                            // Upload Progress or Results
                            if (state is FileUploading) ...[
                              _buildUploadProgress(context, state),
                            ] else if (state is FileUploaded) ...[
                              _buildUploadResult(context, state),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone(BuildContext context, FileShareState state) {
    return DropTarget(
      onDragDone: (detail) async {
        final files = detail.files;
        if (files.isNotEmpty) {
          final file = File(files.first.path);
          final fileName = files.first.name;
          
          // Check file size for drag and drop
          try {
            final fileSize = await file.length();
            if (!_isFileSizeValid(fileSize)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File too large! Maximum size is 100 MB.\nDropped file: ${_formatFileSize(fileSize)}',
                  ),
                  backgroundColor: Colors.red.shade600,
                ),
              );
              return;
            }
            
            context.read<FileShareCubit>().shareFile(file, fileName);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing dropped file: $e')),
            );
          }
        }
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: state is FileSelected ? const Color(0xFF667eea) : const Color(0xFFe1e5e9),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: state is FileSelected ? const Color(0xFF667eea).withOpacity(0.1) : const Color(0xFFf0f0f0),
        ),
        child: InkWell(
          onTap: () => _selectFile(context),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state is FileSelected) ...[
                  Text(_getFileIcon(state.file.path.split('/').last), style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    state.file.path.split('/').last,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: state.file.length(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final size = snapshot.data!;
                        final isValid = _isFileSizeValid(size);
                        return Text(
                          _formatFileSize(size),
                          style: TextStyle(
                            fontSize: 14,
                            color: isValid ? Colors.grey.shade600 : Colors.red.shade600,
                            fontWeight: FontWeight.normal,
                          ),
                        );
                      }
                      return const Text('...', style: TextStyle(fontSize: 14, color: Colors.grey));
                    },
                  ),
                ] else ...[
                  const Text('📁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Drag and drop a file here\nor click to select',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
                if (state is FileSelected) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final file = state.file;
                      context.read<FileShareCubit>().uploadAndShareFile(file);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      '🔐 Encrypt and Share',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildUploadProgress(BuildContext context, FileUploading state) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFf0f0f0), borderRadius: BorderRadius.circular(8)),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔐', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Encrypting and Uploading...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 25,
          decoration: BoxDecoration(
            color: const Color(0xFFf0f0f0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: state.progress,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Center(
                child: Text(
                  '${(state.progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildUploadResult(BuildContext context, FileUploaded state) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFeafaf1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF27ae60), width: 4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'File Shared Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF27ae60)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // URL Section
        const Row(
          children: [
            Text('🔗', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Share URL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFe1e5e9), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(state.url, style: const TextStyle(fontFamily: 'monospace')),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: state.url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Text('📋', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('URL copied to clipboard'),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                tooltip: 'Copy URL',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PIN Section
        const Row(
          children: [
            Text('🔑', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Access PIN:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFe1e5e9), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.pin,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: state.pin));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Text('📋', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('PIN copied to clipboard'),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                tooltip: 'Copy PIN',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Share buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final message = 'File shared via Furl 🔐:\n\n🔗 URL: ${state.url}\n🔑 PIN: ${state.pin}';
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Text('📋', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Share info copied to clipboard'),
                        ],
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('📋 Copy All', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.read<FileShareCubit>().reset();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF667eea), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  '🔄 Share Another',
                  style: TextStyle(color: Color(0xFF667eea), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  // Helper functions for file handling
  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return '🖼️';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return '🎬';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return '🎵';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return '📦';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📋';
      case 'txt':
        return '📄';
      default:
        return '📁';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  bool _isFileSizeValid(int bytes) {
    const maxSizeInBytes = 100 * 1024 * 1024; // 100 MB limit
    return bytes <= maxSizeInBytes;
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Color(0xFF667eea)),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File Upload Limits',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('Maximum file size: 100 MB'),
              const Text('Supported file types: All'),
              const SizedBox(height: 16),
              const Text(
                'Security Features',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• End-to-end encryption'),
              const Text('• Automatic PIN generation'),
              const Text('• Secure atSign authentication'),
              const SizedBox(height: 16),
              const Text(
                'About Furl',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('Version: 1.0.0'),
              const Text('Secure file sharing powered by atSign'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF667eea)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        
        // Check file size
        final fileSize = await file.length();
        if (!_isFileSizeValid(fileSize)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File too large! Maximum size is 100 MB.\nSelected file: ${_formatFileSize(fileSize)}',
              ),
              backgroundColor: Colors.red.shade600,
            ),
          );
          return;
        }

        // Start the file sharing process
        context.read<FileShareCubit>().shareFile(file, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }
