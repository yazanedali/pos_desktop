import 'dart:io';
import 'package:cron/cron.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
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
    try {
      final dbHelper = DatabaseHelper();
      final String currentDbPath = await dbHelper.getDatabasePath();
      final File dbFile = File(currentDbPath);

      if (!await dbFile.exists()) return "قاعدة البيانات الأصلية غير موجودة";

      final String timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final String fileName =
          '${isAuto ? 'auto' : 'manual'}_backup_$timestamp.db';

      // --- التعديل هنا: مسار مباشر على الفلاشة بعيداً عن مجلدات الدرايف ---
      // تأكد أن المسار لا يحتوي على "My Drive" أو أي اسم متعلق بجوجل درايف
      final String backupDirPath = r'D:\POS_System_Backups';
      final String fullPath = join(backupDirPath, fileName);

      final Directory dir = Directory(backupDirPath);

      // فحص وجود الفلاشة (D:)
      if (!await Directory('D:\\').exists()) {
        return "فشل: الفلاشة (القرص D) غير متصلة بالجهاز";
      }

      // إنشاء المجلد إذا لم يكن موجوداً
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // عملية النسخ (Async) لضمان عدم توقف واجهة البيع
      await dbFile.copy(fullPath);

      // تنظيف النسخ القديمة
      await _cleanOldBackups(dir);

      return "تم النسخ بنجاح إلى الفلاشة";
    } catch (e) {
      // في حال وجود خطأ (مثلاً الفلاشة محمية من الكتابة أو مفصولة)
      return "خطأ في الوصول للفلاشة: $e";
    }
  }

  Future<void> _cleanOldBackups(Directory dir) async {
    try {
      // جلب الملفات بشكل غير متزامن تماماً
      List<FileSystemEntity> files = [];
      await for (var entity in dir.list()) {
        if (entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }

      if (files.length > maxBackupCount) {
        // قراءة إحصائيات الملفات (تاريخ التعديل) بدون تجميد الـ UI
        List<Map<String, dynamic>> fileStats = [];
        for (var file in files) {
          FileStat stat = await file.stat();
          fileStats.add({'file': file, 'date': stat.modified});
        }

        // ترتيب من الأقدم للأحدث
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
