// database/customer_queries.dart

import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'dart:math';

class CustomerQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // جلب كل العملاء من قاعدة البيانات
  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers');

    return List.generate(maps.length, (i) {
      return Customer.fromMap(maps[i]);
    });
  }

  // إضافة عميل جديد
  Future<int> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<DebtorInfo>> getDebtorsWithOutstandingBalance() async {
    final db = await _dbHelper.database;

    // استعلام SQL يقوم بربط جدول العملاء بجدول الفواتير
    // ثم يجمع المبالغ المتبقية لكل عميل
    // ويعيد فقط العملاء الذين لديهم دين أكبر من صفر
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        c.id as customerId,
        c.name as customerName,
        SUM(si.remaining_amount) as totalDebt
      FROM customers c
      JOIN sales_invoices si ON c.id = si.customer_id
      WHERE si.remaining_amount > 0
      GROUP BY c.id, c.name
      ORDER BY totalDebt DESC
    ''');

    if (maps.isEmpty) {
      return [];
    }

    // تحويل النتائج إلى قائمة من كائنات DebtorInfo
    return List.generate(maps.length, (i) {
      return DebtorInfo.fromMap(maps[i]);
    });
  }

  Future<List<DebtorInfo>> getAllCustomersWithDebt() async {
    final db = await _dbHelper.database;

    // LEFT JOIN: لجلب كل العملاء حتى لو لم يكن لديهم فواتير
    // COALESCE(SUM(...), 0): إذا كان مجموع الديون null (لعميل جديد)، اجعله 0
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        c.id as customerId,
        c.name as customerName,
        COALESCE(SUM(si.remaining_amount), 0) as totalDebt
      FROM customers c
      LEFT JOIN sales_invoices si ON c.id = si.customer_id AND si.remaining_amount > 0
      GROUP BY c.id, c.name
      ORDER BY totalDebt DESC, c.name ASC
    ''');

    return List.generate(maps.length, (i) {
      return DebtorInfo.fromMap(maps[i]);
    });
  }

  Future<void> settleCustomerDebt(int customerId, double paymentAmount) async {
    final db = await _dbHelper.database;

    // استخدام transaction لضمان تنفيذ كل العمليات كوحدة واحدة
    await db.transaction((txn) async {
      // 1. جلب كل الفواتير غير المسددة بالكامل للعميل، مرتبة من الأقدم للأحدث
      List<Map<String, dynamic>> unpaidInvoices = await txn.query(
        'sales_invoices',
        where: 'customer_id = ? AND remaining_amount > 0',
        whereArgs: [customerId],
        orderBy: 'date ASC, time ASC',
      );

      double remainingPayment = paymentAmount;

      // 2. المرور على الفواتير وتوزيع مبلغ الدفعة عليها
      for (var invoice in unpaidInvoices) {
        if (remainingPayment <= 0) break; // توقف إذا تم توزيع كامل المبلغ

        double debtOnInvoice = (invoice['remaining_amount'] as num).toDouble();
        double paidOnInvoice = (invoice['paid_amount'] as num).toDouble();
        int invoiceId = invoice['id'] as int;

        // تحديد المبلغ الذي سيتم دفعه لهذه الفاتورة تحديدًا
        double amountToPayForThisInvoice = min(remainingPayment, debtOnInvoice);

        // 3. تحديث الفاتورة الحالية في قاعدة البيانات
        await txn.update(
          'sales_invoices',
          {
            'remaining_amount': debtOnInvoice - amountToPayForThisInvoice,
            'paid_amount': paidOnInvoice + amountToPayForThisInvoice,
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 4. إنقاص المبلغ الموزع من إجمالي الدفعة
        remainingPayment -= amountToPayForThisInvoice;
      }
    });
  }
}
