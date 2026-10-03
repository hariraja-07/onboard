import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A backup file the user chose, already read into memory.
class PickedBackup {
  const PickedBackup({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// The file-system side of backup, restore and export.
///
/// Kept behind an interface so the controller's logic — validation, the safety
/// backup, the confirmation flow — can be tested without touching a real
/// picker or disk.
abstract class BackupFileGateway {
  /// Opens the picker for a backup. Returns null if the user cancelled.
  Future<PickedBackup?> pickBackup();

  /// Saves [bytes] to a location the user chooses. Returns a short description
  /// of where it went, or null if the user cancelled.
  Future<String?> saveBackup(Uint8List bytes, String fileName);

  /// Saves an Excel export to a location the user chooses. Returns a short
  /// description, or null if the user cancelled.
  Future<String?> saveExport(Uint8List bytes, String fileName);

  /// Writes a safety copy without asking, and returns its path.
  ///
  /// Used before anything destructive so a mistaken restore or clear can be
  /// undone by restoring the file it wrote.
  Future<String> writeSafetyBackup(Uint8List bytes, String fileName);
}

/// The real gateway, backed by `file_picker` and `path_provider`.
class FilePickerBackupGateway implements BackupFileGateway {
  const FilePickerBackupGateway();

  @override
  Future<PickedBackup?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['onboard', 'json'],
    );
    if (file == null) return null;
    return PickedBackup(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save OnBoard backup',
      fileName: fileName,
      bytes: bytes,
    );
    return saved == null ? null : _describeSavedLocation(saved);
  }

  @override
  Future<String?> saveExport(Uint8List bytes, String fileName) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save data export',
      fileName: fileName,
      bytes: bytes,
    );
    return saved == null ? null : _describeSavedLocation(saved);
  }

  @override
  Future<String> writeSafetyBackup(Uint8List bytes, String fileName) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'OnBoard', 'backups'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _describeSavedLocation(Uri uri) =>
      uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
}
