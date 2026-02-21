import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class FileTools {
  static Future<Map<String, dynamic>> searchFilesByMimeType(String mimeType) async {
    // Check permissions
    if (Platform.isAndroid) {
      if (!(await Permission.storage.request().isGranted) && 
          !(await Permission.manageExternalStorage.request().isGranted)) {
        // Some Android versions don't need this or have different permissions
        // For hackathon, we'll proceed and let FilePicker handle it if possible
      }
    }

    try {
      FileType fileType = FileType.any;
      List<String>? allowedExtensions;
      
      if (mimeType.contains('pdf')) {
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
      } else if (mimeType.contains('image')) {
        fileType = FileType.image;
      } else if (mimeType.contains('video')) {
        fileType = FileType.video;
      } else if (mimeType.contains('audio')) {
        fileType = FileType.audio;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        return {
          'fileName': file.name,
          'filePath': file.path,
          'fileSize': '${(file.size / 1024).toStringAsFixed(1)} KB',
          'mimeType': mimeType,
        };
      } else {
        return {'error': 'No file selected'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> searchFilesRecent(String query) async {
    // For prototype, let's just pick a file
    return await searchFilesByMimeType('application/pdf');
  }

  static Future<Map<String, dynamic>> searchFilesSemantic(String query) async {
    // For prototype, let's just pick a file
    return await searchFilesByMimeType('application/pdf');
  }

  static Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}
