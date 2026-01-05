import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

/// Service for backup and restore of app database
class BackupService {
  static const String _dbFileName = 'db.sqlite';

  /// Get the path to the database file
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return '${dbFolder.path}/$_dbFileName';
  }

  /// Create a backup of the database and share it
  static Future<String?> backupDatabase() async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return null;
      }

      // Create backup file with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final backupFileName = 'RiceAgent_Backup_$timestamp.db';

      // Copy to temporary location for sharing
      final tempDir = await getTemporaryDirectory();
      final backupPath = '${tempDir.path}/$backupFileName';
      await dbFile.copy(backupPath);

      // Share the backup file
      await Share.shareXFiles(
        [XFile(backupPath)],
        text: 'RiceAgent Database Backup - $timestamp',
      );

      return backupPath;
    } catch (e) {
      return null;
    }
  }

  /// Restore database from a backup file
  /// Returns true if successful, false otherwise
  static Future<bool> restoreDatabase() async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return false;
      }

      final selectedFile = result.files.first;
      if (selectedFile.path == null) {
        return false;
      }

      final backupFile = File(selectedFile.path!);
      if (!await backupFile.exists()) {
        return false;
      }

      // Validate it's a valid SQLite file (check magic bytes)
      final bytes = await backupFile.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(6));
      if (header != 'SQLite') {
        return false;
      }

      // Get current database path and replace
      final dbPath = await getDatabasePath();
      await backupFile.copy(dbPath);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the downloads folder path
  static Future<String> getDownloadsPath() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory.path;
      }
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}
