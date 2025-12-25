import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/supplier.dart';

class SupplierQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // جلب كل الموردين
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      orderBy: 'name ASC',
    );

    // نحتاج نحسب الرصيد لكل مورد
    List<Supplier> suppliers = [];
    for (var map in maps) {
      double balance = await getSupplierBalance(map['id']);
      // نضيف الرصيد للماب قبل التحويل
      Map<String, dynamic> mapWithBalance = Map.from(map);
      mapWithBalance['balance'] = balance;
      suppliers.add(Supplier.fromMap(mapWithBalance));
    }
    return suppliers;
  }

  Future<List<Supplier>> searchSuppliers({String? searchTerm}) async {
    final db = await DatabaseHelper().database;

    if (searchTerm == null || searchTerm.isEmpty) {
      return getAllSuppliers();
    }

    final results = await db.rawQuery(
      '''
      SELECT * FROM suppliers 
      WHERE 
        name LIKE ? OR
        phone LIKE ? OR
        address LIKE ?
      ORDER BY name ASC
    ''',
      ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
    );

    return results.map((map) => Supplier.fromMap(map)).toList();
  }

  // التحقق من وجود معاملات للمورد
  Future<bool> hasSupplierTransactions(int supplierId) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count 
      FROM purchase_invoices 
      WHERE supplier_id = ?
    ''',
      [supplierId],
    );

    return ((result.first['count'] as int?) ?? 0) > 0;
  }

  // إضافة مورد جديد
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  // تحديث بيانات مورد
  Future<void> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  // حذف مورد
  Future<void> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // حساب رصيد المورد (المبلغ المتبقي له عندنا)
  // المعادلة: مجموع (remaining_amount) للفواتير "غير المدفوعة" أو "الجزئية"
  Future<double> getSupplierBalance(int supplierId) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(remaining_amount) as total
      FROM purchase_invoices
      WHERE supplier_id = ? AND remaining_amount > 0
    ''',
      [supplierId],
    );

    String? totalStr = result.first['total']?.toString();
    return double.tryParse(totalStr ?? '0') ?? 0.0;
  }

  // سداد دفعة للمورد
  Future<void> paySupplier(int supplierId, double amount, String notes) async {
    final db = await _dbHelper.database;

    // 1. جلب الفواتير المستحقة (الأقدم أولاً)
    final invoices = await db.query(
      'purchase_invoices',
      where: 'supplier_id = ? AND remaining_amount > 0',
      orderBy: 'date ASC, time ASC',
      whereArgs: [supplierId],
    );

    double remainingPayment = amount;

    await db.transaction((txn) async {
      for (var invoice in invoices) {
        if (remainingPayment <= 0) break;

        double debtOnInvoice = (invoice['remaining_amount'] as num).toDouble();
        double paidOnInvoice = (invoice['paid_amount'] as num).toDouble();
        int invoiceId = invoice['id'] as int;

        double amountToPayForThisInvoice = 0.0;
        if (remainingPayment >= debtOnInvoice) {
          amountToPayForThisInvoice = debtOnInvoice;
        } else {
          amountToPayForThisInvoice = remainingPayment;
        }

        double newRemaining = debtOnInvoice - amountToPayForThisInvoice;
        double newPaid = paidOnInvoice + amountToPayForThisInvoice;

        String newStatus = newRemaining <= 0 ? 'مدفوع' : 'جزئي';

        await txn.update(
          'purchase_invoices',
          {
            'remaining_amount': newRemaining,
            'paid_amount': newPaid,
            'payment_status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // يمكننا هنا إضافة سجل "سند صرف" إذا أردنا توثيق العملية بشكل أدق
        // لكن حالياً نكتفي بتحديث الفواتير
        remainingPayment -= amountToPayForThisInvoice;
      }
    });
  }
}
