// lib\database\cash_queries.dart
import '../database/database_helper.dart';
import '../models/cash_box.dart';
import '../models/cash_movement.dart';

class CashQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // الحصول على جميع الصناديق
  Future<List<CashBox>> getAllCashBoxes() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('cash_boxes');
    return List.generate(maps.length, (i) => CashBox.fromMap(maps[i]));
  }

  // الحصول على صندوق بالاسم
  Future<CashBox?> getCashBoxByName(String name) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_boxes',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return CashBox.fromMap(maps.first);
  }

  // تحديث رصيد الصندوق
  Future<void> updateBoxBalance(
    int boxId,
    double amount,
    String direction,
  ) async {
    final db = await _dbHelper.database;
    final boxMap = await db.query(
      'cash_boxes',
      where: 'id = ?',
      whereArgs: [boxId],
    );
    if (boxMap.isEmpty) return;

    final currentBalance = (boxMap.first['balance'] as num).toDouble();
    double newBalance;
    if (direction == 'داخل') {
      newBalance = currentBalance + amount;
    } else {
      newBalance = currentBalance - amount;
    }

    await db.update(
      'cash_boxes',
      {'balance': newBalance, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [boxId],
    );
  }

  // إضافة حركة صندوق
  Future<int> addCashMovement(CashMovement movement) async {
    final db = await _dbHelper.database;

    // إدراج الحركة
    final id = await db.insert('cash_movements', movement.toMap());

    // تحديث رصيد الصندوق المقابل آلياً
    await updateBoxBalance(movement.boxId, movement.amount, movement.direction);

    return id;
  }

  // الحصول على أرصدة الصناديق فوراً (مفيد للعرض السريع)
  Future<Map<String, double>> getBoxBalances() async {
    final boxes = await getAllCashBoxes();
    final Map<String, double> balances = {};
    for (var box in boxes) {
      balances[box.name] = box.balance;
    }
    return balances;
  }

  // في cash_queries.dart
  Future<List<Map<String, dynamic>>> getMovementHistory({
    int? limit = 100,
    List<String>? types,
  }) async {
    final db = await _dbHelper.database;

    // بناء الاستعلام
    var query = '''
    SELECT m.*, b.name as box_name
    FROM cash_movements m
    JOIN cash_boxes b ON m.box_id = b.id
  ''';

    final List<dynamic> whereArgs = [];

    // إضافة فلتر الأنواع إذا كان موجودًا
    if (types != null && types.isNotEmpty) {
      final placeholders = List.filled(types.length, '?').join(',');
      query += ' WHERE m.type IN ($placeholders)';
      whereArgs.addAll(types);
    }

    // الترتيب حسب التاريخ والوقت تنازليًا (الأحدث أولاً)
    query += ' ORDER BY m.date DESC, m.time DESC';

    // إضافة حد عدد النتائج
    if (limit != null) {
      query += ' LIMIT ?';
      whereArgs.add(limit);
    }

    return await db.rawQuery(query, whereArgs);
  }

  // حذف حركة بدون التأثير على الأرصدة
  Future<int> deleteMovement(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('cash_movements', where: 'id = ?', whereArgs: [id]);
  }
}
