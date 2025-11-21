// database/customer_queries.dart

import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/CustomerDebtDetail.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'dart:math';

import 'package:pos_desktop/models/report_models.dart';

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

    //   ***** الاستعلام الآن أبسط وأكثر دقة *****
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        c.id as customerId,
        c.name as customerName,
        -- فقط اجمع المبالغ المتبقية من كل الفواتير (بما في ذلك فاتورة الدين الافتتاحي)
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

        // حساب القيم الجديدة
        double newRemaining = debtOnInvoice - amountToPayForThisInvoice;
        double newPaidAmount = paidOnInvoice + amountToPayForThisInvoice;

        // تحديد حالة الدفع ونوعه بناءً على القيم الجديدة
        String newPaymentStatus;
        String newPaymentType;

        if (newRemaining <= 0) {
          // إذا أصبح المتبقي صفر أو أقل، الفاتورة مدفوعة بالكامل
          newPaymentStatus = 'مدفوع';
          newPaymentType = 'نقدي';
        } else if (newPaidAmount > 0) {
          // إذا دفع جزء من الفاتورة
          newPaymentStatus = 'جزئي';
          newPaymentType = 'آجل';
        } else {
          // إذا ما دفع ولا قرش (حالة احتياطية)
          newPaymentStatus = 'غير مدفوع';
          newPaymentType = 'آجل';
        }

        // 3. تحديث الفاتورة الحالية في قاعدة البيانات
        await txn.update(
          'sales_invoices',
          {
            'remaining_amount': newRemaining,
            'paid_amount': newPaidAmount,
            'payment_status': newPaymentStatus,
            'payment_type': newPaymentType,
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 4. إضافة سجل السداد في جدول payment_records
        final now = DateTime.now();
        await txn.insert('payment_records', {
          'invoice_id': invoiceId,
          'payment_date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'payment_time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          'amount': amountToPayForThisInvoice,
          'payment_method': 'نقدي',
          'notes': 'سداد دين من صفحة العملاء',
          'created_at': now.toIso8601String(),
        });
        // 6. إنقاص المبلغ الموزع من إجمالي الدفعة
        remainingPayment -= amountToPayForThisInvoice;
      }
    });
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await _dbHelper.database;

    await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);
  }

  Future<bool> canDeleteCustomer(int customerId) async {
    final debtor = await getCustomerById(customerId);
    if (debtor == null) return false;

    // جلب مجموع ديون هذا العميل
    final result = await getAllCustomersWithDebt();

    final info = result.firstWhere(
      (d) => d.customerId == customerId,
      orElse:
          () => DebtorInfo(
            customerId: customerId,
            customerName: '',
            totalDebt: 0,
          ),
    );

    return info.totalDebt == 0;
  }

  Future<void> insertCustomerWithOpeningBalance(
    Map<String, dynamic> customerData,
  ) async {
    final db = await _dbHelper.database;
    final double openingBalance = customerData['opening_balance'] as double;

    await db.transaction((txn) async {
      final newCustomerId = await txn.insert('customers', {
        'name': customerData['name'],
        'phone': customerData['phone'],
        'address': customerData['address'],
      });

      if (openingBalance > 0) {
        final now = DateTime.now();
        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final time =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        await txn.insert('sales_invoices', {
          'invoice_number':
              'OP-BAL-$newCustomerId-${now.millisecondsSinceEpoch}',
          'date': date,
          'time': time,
          'total': openingBalance,
          'paid_amount': 0.0,
          'remaining_amount': openingBalance,
          'cashier': 'النظام',
          'customer_id': newCustomerId,
          'payment_method': 'رصيد افتتاحي',
          'notes': customerData['notes'],
          'created_at': now.toIso8601String(),
        });
      }
    });
  }

  Future<void> adjustCustomerTotalDebt(
    int customerId,
    double currentDebt,
    double newDebt,
  ) async {
    final db = await _dbHelper.database;

    final double difference = newDebt - currentDebt;

    // إذا لم يكن هناك تغيير، لا تفعل شيئاً
    if (difference.abs() < 0.01) return;

    // إذا كان الدين الجديد أقل (تسديد أو خصم)
    if (difference < 0) {
      // استخدم نفس منطق السداد السابق لتوزيع الخصم على الفواتير
      // الفرق السالب سيتم تحويله إلى موجب لتمريره لدالة السداد
      await settleCustomerDebt(customerId, -difference);
    }
    // إذا كان الدين الجديد أكبر (إضافة دين)
    else {
      // قم بإنشاء فاتورة وهمية جديدة بقيمة الفرق
      final now = DateTime.now();
      await db.insert('sales_invoices', {
        'invoice_number': 'ADJ-$customerId-${now.millisecondsSinceEpoch}',
        'date':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'total': difference,
        'paid_amount': 0.0,
        'remaining_amount': difference,
        'cashier': 'النظام',
        'customer_id': customerId,
        'payment_method': 'تسوية دين',
        'notes': 'تعديل يدوي لإجمالي الرصيد.',
        'created_at': now.toIso8601String(),
      });
    }
  }

  Future<List<CustomerDebtDetail>> getCustomerDebtDetails(
    int customerId,
  ) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        si.id as invoice_id,
        si.invoice_number,
        si.date,
        si.time,
        si.total,
        si.paid_amount,
        si.remaining_amount,
        si.payment_type,
        si.payment_status,
        si.created_at
      FROM sales_invoices si
      WHERE si.customer_id = ? AND si.remaining_amount > 0
      ORDER BY si.date ASC, si.time ASC
    ''',
      [customerId],
    );

    return List.generate(maps.length, (i) {
      return CustomerDebtDetail(
        invoiceId: maps[i]['invoice_id'],
        invoiceNumber: maps[i]['invoice_number'],
        date: maps[i]['date'],
        time: maps[i]['time'],
        totalAmount: (maps[i]['total'] as num).toDouble(),
        paidAmount: (maps[i]['paid_amount'] as num).toDouble(),
        remainingAmount: (maps[i]['remaining_amount'] as num).toDouble(),
        paymentType: maps[i]['payment_type'],
        paymentStatus: maps[i]['payment_status'],
        createdAt: maps[i]['created_at'],
      );
    });
  }

  // دالة لجلب إحصائيات الدفع للتقارير
  Future<PaymentStatistics> getPaymentStatistics(String from, String to) async {
    final db = await _dbHelper.database;

    final cashSales = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, COALESCE(SUM(total), 0) as total
      FROM sales_invoices 
      WHERE date BETWEEN ? AND ? AND payment_type = 'نقدي'
    ''',
      [from, to],
    );

    final creditSales = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, COALESCE(SUM(total), 0) as total
      FROM sales_invoices 
      WHERE date BETWEEN ? AND ? AND payment_type = 'آجل'
    ''',
      [from, to],
    );

    final paymentRecords = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
      FROM payment_records 
      WHERE payment_date BETWEEN ? AND ?
    ''',
      [from, to],
    );

    return PaymentStatistics(
      cashInvoices: cashSales.first['count'] as int,
      cashTotal: (cashSales.first['total'] as num).toDouble(),
      creditInvoices: creditSales.first['count'] as int,
      creditTotal: (creditSales.first['total'] as num).toDouble(),
      paymentRecordsCount: paymentRecords.first['count'] as int,
      paymentRecordsTotal: (paymentRecords.first['total'] as num).toDouble(),
    );
  }
}
