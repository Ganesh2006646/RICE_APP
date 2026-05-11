import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for backup and restore of app database
class BackupService {
  static const String _dbFileName = 'db.sqlite';
  static const String _autoBackupDirName = 'backups';
  static const String _lastBackupKey = 'last_auto_backup_time';
  static const String _pendingRestoreKey = 'pending_db_restore';
  static const String _pendingRestoreFileName = 'db_restore_pending.sqlite';
  static const int _maxBackups = 5;

  /// Get the path to the database file
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return '${dbFolder.path}/$_dbFileName';
  }

  /// Get the auto-backup directory path (app-scoped external storage)
  static Future<String> getAutoBackupDirectory() async {
    try {
      Directory? baseDir;

      if (Platform.isAndroid) {
        // Use app-scoped external storage (doesn't require permissions)
        baseDir = await getExternalStorageDirectory();
      }

      // Fallback to app documents directory
      baseDir ??= await getApplicationDocumentsDirectory();

      final backupDir = Directory('${baseDir.path}/$_autoBackupDirName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      debugPrint('[BackupService] Backup directory: ${backupDir.path}');
      return backupDir.path;
    } catch (e) {
      debugPrint('[BackupService] Error getting backup directory: $e');
      // Ultimate fallback
      final docs = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory('${docs.path}/$_autoBackupDirName');
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir.path;
    }
  }

  /// Perform auto-backup if enabled and due
  /// Call this from main.dart during app initialization
  static Future<void> performAutoBackupIfNeeded(bool autoBackupEnabled) async {
    try {
      if (!autoBackupEnabled) {
        debugPrint('[BackupService] Auto-backup disabled, skipping.');
        return;
      }

      final isDue = await isBackupDue();
      if (!isDue) {
        debugPrint('[BackupService] Backup not due yet, skipping.');
        return;
      }

      debugPrint('[BackupService] Starting auto-backup...');
      final result = await autoBackup();
      if (result != null) {
        debugPrint('[BackupService] Auto-backup successful: $result');
      } else {
        debugPrint('[BackupService] Auto-backup failed.');
      }
    } catch (e) {
      debugPrint('[BackupService] Auto-backup error: $e');
      // Silent failure - don't crash the app
    }
  }

  /// Perform silent auto-backup (no share dialog)
  /// Returns the backup path if successful, null otherwise
  static Future<String?> autoBackup() async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        debugPrint('[BackupService] Database file not found at: $dbPath');
        return null;
      }

      final backupDir = await getAutoBackupDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final backupFileName = 'RiceAgent_Auto_$timestamp.db';
      final backupPath = '$backupDir/$backupFileName';

      await dbFile.copy(backupPath);
      debugPrint('[BackupService] Backup created: $backupPath');

      // Update last backup time
      await setLastAutoBackupTime(DateTime.now());

      // Cleanup old backups (keep only last 5)
      await cleanupOldBackups();

      return backupPath;
    } catch (e) {
      debugPrint('[BackupService] Auto-backup failed: $e');
      return null;
    }
  }

  /// Get the last auto-backup timestamp
  static Future<DateTime?> getLastAutoBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isoString = prefs.getString(_lastBackupKey);
      if (isoString != null && isoString.isNotEmpty) {
        return DateTime.parse(isoString);
      }
    } catch (e) {
      debugPrint('[BackupService] Error reading last backup time: $e');
    }
    return null;
  }

  /// Set the last auto-backup timestamp
  static Future<void> setLastAutoBackupTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, time.toIso8601String());
    } catch (e) {
      debugPrint('[BackupService] Error saving last backup time: $e');
    }
  }

  /// Check if backup is due (24+ hours since last backup)
  static Future<bool> isBackupDue() async {
    final lastBackup = await getLastAutoBackupTime();
    if (lastBackup == null) {
      debugPrint('[BackupService] No previous backup found, backup is due.');
      return true;
    }

    final hoursSinceBackup = DateTime.now().difference(lastBackup).inHours;
    debugPrint('[BackupService] Hours since last backup: $hoursSinceBackup');
    return hoursSinceBackup >= 24;
  }

  /// Cleanup old backups, keeping only the most recent ones
  static Future<void> cleanupOldBackups() async {
    try {
      final backupDir = Directory(await getAutoBackupDirectory());
      if (!await backupDir.exists()) return;

      final files = await backupDir
          .list()
          .where((entity) =>
              entity is File && entity.path.contains('RiceAgent_Auto_'))
          .cast<File>()
          .toList();

      if (files.length <= _maxBackups) {
        debugPrint(
            '[BackupService] ${files.length} backups found, no cleanup needed.');
        return;
      }

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete oldest files beyond the limit
      int deleted = 0;
      for (int i = _maxBackups; i < files.length; i++) {
        await files[i].delete();
        deleted++;
      }
      debugPrint('[BackupService] Cleaned up $deleted old backup(s).');
    } catch (e) {
      debugPrint('[BackupService] Cleanup error: $e');
    }
  }

  /// Create a backup of the database and return the local backup path.
  static Future<String?> backupDatabase() async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        debugPrint('[BackupService] Database not found for manual backup.');
        return null;
      }

      // Create backup file with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final backupFileName = 'RiceAgent_Manual_$timestamp.db';

      // Persist manual backups in the backup directory so they survive cleanup
      // of temporary folders and can be restored later.
      final backupDir = await getAutoBackupDirectory();
      final backupPath = '$backupDir/$backupFileName';
      await dbFile.copy(backupPath);

      debugPrint('[BackupService] Manual backup created: $backupPath');

      return backupPath;
    } catch (e) {
      debugPrint('[BackupService] Manual backup failed: $e');
      return null;
    }
  }

  /// Stage database restore from a user-selected backup file.
  /// The actual replacement is applied on next app start (before DB opens).
  /// Returns true if staging was successful.
  static Future<bool> restoreDatabase() async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[BackupService] No file selected for restore.');
        return false;
      }

      final selectedFile = result.files.first;
      if (selectedFile.path == null) {
        debugPrint('[BackupService] Selected file has no path.');
        return false;
      }

      final backupFile = File(selectedFile.path!);
      if (!await backupFile.exists()) {
        debugPrint('[BackupService] Backup file does not exist.');
        return false;
      }

      if (!await _isLikelySqliteFile(backupFile)) {
        debugPrint('[BackupService] Invalid SQLite file.');
        return false;
      }

      // Stage restore file for next launch. Avoid replacing an open DB file.
      final dbFolder = await getApplicationDocumentsDirectory();
      final stagedFile = File('${dbFolder.path}/$_pendingRestoreFileName');
      if (await stagedFile.exists()) {
        await stagedFile.delete();
      }
      await backupFile.copy(stagedFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingRestoreKey, true);

      debugPrint('[BackupService] Database restore staged: ${stagedFile.path}');
      return true;
    } catch (e) {
      debugPrint('[BackupService] Restore failed: $e');
      return false;
    }
  }

  /// Apply a staged restore before opening the app database.
  static Future<bool> applyPendingRestoreIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool(_pendingRestoreKey) ?? false;
      final dbFolder = await getApplicationDocumentsDirectory();
      final stagedFile = File('${dbFolder.path}/$_pendingRestoreFileName');

      if (!pending && !await stagedFile.exists()) {
        return false;
      }

      if (!await stagedFile.exists()) {
        await prefs.setBool(_pendingRestoreKey, false);
        return false;
      }

      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await stagedFile.copy(dbPath);
      await stagedFile.delete();
      await prefs.setBool(_pendingRestoreKey, false);
      debugPrint('[BackupService] Pending database restore applied.');
      return true;
    } catch (e) {
      debugPrint('[BackupService] Failed to apply pending restore: $e');
      return false;
    }
  }

  static Future<bool> _isLikelySqliteFile(File file) async {
    try {
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(6));
      return header == 'SQLite';
    } catch (_) {
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
