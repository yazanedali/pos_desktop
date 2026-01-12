import 'dart:io';
import 'package:cron/cron.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'database_helper.dart';

class BackupService {
  final Cron _cron = Cron();
  final int maxBackupCount = 5; // الحد الأقصى لعدد الملفات

  // تشغيل الجدولة التلقائية
  void startScheduledBackup() {
    print("Backup Scheduler Started...");
    _cron.schedule(Schedule.parse('0 */6 * * *'), () async {
      print("Starting scheduled backup...");
      await createBackup(isAuto: true);
    });
  }

  // دالة إنشاء النسخة الاحتياطية
  Future<String> createBackup({bool isAuto = false}) async {
    try {
      final dbHelper = DatabaseHelper();
      final String currentDbPath = await dbHelper.getDatabasePath();
      final File dbFile = File(currentDbPath);

      if (!await dbFile.exists()) return "قاعدة البيانات غير موجودة";

      final DateTime now = DateTime.now();
      final String timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final String fileName =
          '${isAuto ? 'auto' : 'manual'}_backup_$timestamp.db';

      // مسار المجلد على جوجل درايف
      final String backupDirPath = r'G:\My Drive\POS_Backups';
      final String drivePath = join(backupDirPath, fileName);

      try {
        // 1. التأكد من وجود المجلد
        final Directory dir = Directory(backupDirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // 2. عمل النسخة الجديدة
        await dbFile.copy(drivePath);

        // 3. تنظيف الملفات القديمة (الإبقاء على آخر 5 فقط)
        await _cleanOldBackups(dir);

        return "تم النسخ بنجاح (تم الإبقاء على آخر $maxBackupCount نسخ)";
      } catch (e) {
        return "فشل الوصول للدرايف: $e";
      }
    } catch (e) {
      return "فشل النسخ الاحتياطي بالكامل: $e";
    }
  }

  // دالة حذف الملفات القديمة
  Future<void> _cleanOldBackups(Directory dir) async {
    try {
      // جلب قائمة الملفات التي تنتهي بـ .db
      List<FileSystemEntity> files =
          dir.listSync().where((file) => file.path.endsWith('.db')).toList();

      // إذا كان عدد الملفات أكبر من الحد المسموح
      if (files.length > maxBackupCount) {
        // ترتيب الملفات حسب تاريخ التعديل (الأقدم أولاً)
        files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );

        // حساب كم ملف يجب حذفه
        int filesToDeleteCount = files.length - maxBackupCount;

        for (int i = 0; i < filesToDeleteCount; i++) {
          print("Deleting old backup: ${files[i].path}");
          await files[i].delete();
        }
      }
    } catch (e) {
      print("Error cleaning old backups: $e");
    }
  }

  void dispose() {
    _cron.close();
  }
}
