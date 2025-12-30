// lib/database/customer_queries.dart

import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/CustomerDebtDetail.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'dart:math';
import 'package:pos_desktop/models/report_models.dart';

class CustomerQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // جلب كل العملاء
  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  // إضافة عميل جديد
  Future<int> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  // جلب الديون المتراكمة (للمتعثرين فقط)
  Future<List<DebtorInfo>> getDebtorsWithOutstandingBalance() async {
    final db = await _dbHelper.database;
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

    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => DebtorInfo.fromMap(maps[i]));
  }

  // جلب جميع العملاء مع ديونهم وأرصدة محافظهم (يدعم البحث)
  Future<List<DebtorInfo>> getAllCustomersWithDebt({
    String searchTerm = '',
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (searchTerm.isNotEmpty) {
      whereClause = '(c.name LIKE ? OR c.phone LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%']);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        c.id as customerId,
        c.name as customerName,
        c.phone as phone,
        c.address as address,
        c.wallet_balance as walletBalance,
        COALESCE(SUM(si.remaining_amount), 0) as totalDebt
      FROM customers c
      LEFT JOIN sales_invoices si ON c.id = si.customer_id AND si.remaining_amount > 0
      WHERE $whereClause
      GROUP BY c.id, c.name, c.phone, c.address, c.wallet_balance
      ORDER BY totalDebt DESC, c.name ASC
    ''', whereArgs);

    return List.generate(maps.length, (i) => DebtorInfo.fromMap(maps[i]));
  }

  // تسديد دين محدد بمبلغ معين
  Future<void> settleCustomerDebt(int customerId, double paymentAmount) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      List<Map<String, dynamic>> unpaidInvoices = await txn.query(
        'sales_invoices',
        where: 'customer_id = ? AND remaining_amount > 0',
        whereArgs: [customerId],
        orderBy: 'date ASC, time ASC',
      );

      double remainingPayment = paymentAmount;
      final now = DateTime.now();

      for (var invoice in unpaidInvoices) {
        if (remainingPayment <= 0) break;

        double debtOnInvoice = (invoice['remaining_amount'] as num).toDouble();
        double paidOnInvoice = (invoice['paid_amount'] as num).toDouble();
        int invoiceId = invoice['id'] as int;

        double amountToPayForThisInvoice = min(remainingPayment, debtOnInvoice);

        double newRemaining = debtOnInvoice - amountToPayForThisInvoice;
        double newPaidAmount = paidOnInvoice + amountToPayForThisInvoice;

        String newPaymentStatus = newRemaining <= 0 ? 'مدفوع' : 'جزئي';
        // لا نغير نوع الدفع الأصلي للفاتورة (آجل) عادة، ولكن نحدث الحالة
        // أو يمكن تحديثه إذا أصبحت مدفوعة بالكامل، الخيار لك.
        // هنا سنبقيه كما هو أو نحدثه حسب منطقك السابق:
        String newPaymentType = newRemaining <= 0 ? 'نقدي' : 'آجل';

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
    if (maps.isNotEmpty) return Customer.fromMap(maps.first);
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
        await txn.insert('sales_invoices', {
          'invoice_number':
              'OP-BAL-$newCustomerId-${now.millisecondsSinceEpoch}',
          'date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
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

    if (difference.abs() < 0.01) return;

    if (difference < 0) {
      await settleCustomerDebt(customerId, -difference);
    } else {
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

  // تحديث رصيد المحفظة للعميل مع سداد الدين تلقائياً إذا كان إيداع
  Future<void> updateCustomerWallet(
    int customerId,
    double amount, {
    bool isDeposit = true,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> maps = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      );
      if (maps.isEmpty) return;

      double currentWallet = (maps.first['wallet_balance'] as num).toDouble();
      final now = DateTime.now();

      if (isDeposit) {
        // التحقق من الديون
        final List<Map<String, dynamic>> debtItems = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(remaining_amount), 0) as totalDebt
          FROM sales_invoices
          WHERE customer_id = ? AND remaining_amount > 0
        ''',
          [customerId],
        );

        double totalDebt = (debtItems.first['totalDebt'] as num).toDouble();

        if (totalDebt > 0) {
          double amountToSettle = min(amount, totalDebt);

          List<Map<String, dynamic>> unpaidInvoices = await txn.query(
            'sales_invoices',
            where: 'customer_id = ? AND remaining_amount > 0',
            whereArgs: [customerId],
            orderBy: 'date ASC, time ASC',
          );

          double remainingPayment = amountToSettle;
          for (var invoice in unpaidInvoices) {
            if (remainingPayment <= 0) break;
            double debtOnInv = (invoice['remaining_amount'] as num).toDouble();
            double paidOnInv = (invoice['paid_amount'] as num).toDouble();
            int invId = invoice['id'] as int;
            double toPay = min(remainingPayment, debtOnInv);

            await txn.update(
              'sales_invoices',
              {
                'remaining_amount': debtOnInv - toPay,
                'paid_amount': paidOnInv + toPay,
                'payment_status': (debtOnInv - toPay) <= 0 ? 'مدفوع' : 'جزئي',
              },
              where: 'id = ?',
              whereArgs: [invId],
            );

            // **إضافة مهمة: تسجيل حركة السداد لضمان دقة التقارير**
            await txn.insert('payment_records', {
              'invoice_id': invId,
              'payment_date':
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
              'payment_time':
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
              'amount': toPay,
              'payment_method': 'محفظة', // تميز الحركة بأنها عبر المحفظة
              'notes': 'سداد آلي عند الإيداع في المحفظة',
              'created_at': now.toIso8601String(),
            });

            remainingPayment -= toPay;
          }

          double surplus = amount - amountToSettle;
          if (surplus > 0) {
            await txn.update(
              'customers',
              {'wallet_balance': currentWallet + surplus},
              where: 'id = ?',
              whereArgs: [customerId],
            );
          }
        } else {
          // لا يوجد دين، المبلغ كامل للمحفظة
          await txn.update(
            'customers',
            {'wallet_balance': currentWallet + amount},
            where: 'id = ?',
            whereArgs: [customerId],
          );
        }
      } else {
        // سحب من المحفظة
        await txn.update(
          'customers',
          {'wallet_balance': currentWallet - amount},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }
    });
  }

  // في database/customer_queries.dart
  // في customer_queries.dart، أعد كتابة الدالة:
  Future<void> payCustomerFromCashbox(
    int customerId,
    double amount,
    String boxName,
    String? notes,
  ) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // جلب العميل
      final List<Map<String, dynamic>> customerData = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      );

      if (customerData.isEmpty) {
        throw Exception('العميل غير موجود');
      }

      // زيادة رصيد المحفظة (دين منك للعميل)
      double currentWallet =
          (customerData.first['wallet_balance'] as num).toDouble();
      double newWalletBalance = currentWallet + amount;

      await txn.update(
        'customers',
        {'wallet_balance': newWalletBalance},
        where: 'id = ?',
        whereArgs: [customerId],
      );

      // تسجيل الحركة (اختياري - إذا كنت تريد تتبع مدفوعات الصندوق)
      final now = DateTime.now();
      try {
        await txn.insert('customer_cashbox_payments', {
          'customer_id': customerId,
          'amount': amount,
          'box_name': boxName,
          'date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'notes': notes ?? 'دفع من الصندوق للعميل',
          'created_at': now.toIso8601String(),
        });
      } catch (e) {
        // إذا كان الجدول غير موجود، تخطي الخطأ
        print('ملاحظة: جدول customer_cashbox_payments غير موجود: $e');
      }
    });
  }
}
