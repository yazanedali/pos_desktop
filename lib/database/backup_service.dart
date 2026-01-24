import 'dart:io';
import 'package:cron/cron.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class BackupService {
  final Cron _cron = Cron();
  final int maxBackupCount = 5;

  void startScheduledBackup() {
    // جدولة كل 6 ساعات
    _cron.schedule(Schedule.parse('0 */6 * * *'), () async {
      await createBackup(isAuto: true);
    });
  }

  Future<String> createBackup({bool isAuto = false}) async {
    File? tempBackupFile;
    try {
      final dbHelper = DatabaseHelper();
      // Ensure local DB is open
      final db = await dbHelper.database;

      final String timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final String fileName =
          '${isAuto ? 'auto' : 'manual'}_backup_$timestamp.db';

      // 1. Create a temporary backup on the fast local drive (C:)
      // VACUUM INTO creates a transaction-consistent backup without long locks
      final directory = await getApplicationDocumentsDirectory();
      final String tempPath = join(directory.path, 'temp_$fileName');

      await db.execute('VACUUM INTO ?', [tempPath]);

      tempBackupFile = File(tempPath);

      if (!await tempBackupFile.exists()) {
        return "فشل إنشاء النسخة المؤقتة";
      }

      // 2. Define Flash Drive path
      final String backupDirPath = r'D:\POS_System_Backups';
      final String fullPath = join(backupDirPath, fileName);
      final Directory dir = Directory(backupDirPath);

      // Check for Flash Drive
      if (!await Directory('D:\\').exists()) {
        await tempBackupFile.delete();
        return "فشل: الفلاشة (القرص D) غير متصلة بالجهاز";
      }

      // Create directory if needed
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 3. Copy from Temp to Flash Drive
      // This is the slow part, but it no longer locks the DB
      await tempBackupFile.copy(fullPath);

      // 4. Clean up temp file
      await tempBackupFile.delete();

      // Clean old backups on Flash Drive
      await _cleanOldBackups(dir);

      return "تم النسخ بنجاح إلى الفلاشة";
    } catch (e) {
      // Clean up temp file on error
      if (tempBackupFile != null && await tempBackupFile.exists()) {
        try {
          await tempBackupFile.delete();
        } catch (_) {}
      }
      return "خطأ في عملية النسخ: $e";
    }
  }

  Future<void> _cleanOldBackups(Directory dir) async {
    try {
      // Get files asynchronously
      List<FileSystemEntity> files = [];
      await for (var entity in dir.list()) {
        if (entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }

      if (files.length > maxBackupCount) {
        List<Map<String, dynamic>> fileStats = [];
        for (var file in files) {
          FileStat stat = await file.stat();
          fileStats.add({'file': file, 'date': stat.modified});
        }

        // Sort oldest to newest
        fileStats.sort((a, b) => a['date'].compareTo(b['date']));

        int toDelete = fileStats.length - maxBackupCount;
        for (int i = 0; i < toDelete; i++) {
          await (fileStats[i]['file'] as FileSystemEntity).delete();
        }
      }
    } catch (e) {
      print("Cleaning error: $e");
    }
  }

  void dispose() {
    _cron.close();
  }
}
