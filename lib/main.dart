import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pos_desktop/database/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. تهيئة وتشغيل خدمة النسخ الاحتياطي في الخلفية
  final backupService = BackupService();
  // 1. تشغيل نسخة فورية عند فتح البرنامج (لسد فجوة الوقت اللي كان فيها الجهاز طافي)
  backupService.createBackup(isAuto: true);
  // 2. تشغيل الجدولة الدورية
  backupService.startScheduledBackup();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام نقاط البيع',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Tajawal',
        useMaterial3: true,
      ),
      home: const App(),
      debugShowCheckedModeBanner: false,
    );
  }
}
