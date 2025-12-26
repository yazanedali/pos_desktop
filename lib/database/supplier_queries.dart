import 'package:sqflite/sqflite.dart';
import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/supplier.dart';
import 'package:pos_desktop/models/supplier_balance_transaction.dart';
import 'package:pos_desktop/models/supplier_payment.dart';

class SupplierQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // مساعد: تحويل dynamic إلى int بشكل آمن
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  // مساعد: تحويل dynamic إلى String بشكل آمن
  String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  // مساعد: تحويل dynamic إلى double بشكل آمن
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // جلب كل الموردين
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      orderBy: 'name ASC',
    );

    List<Supplier> suppliers = [];
    for (var map in maps) {
      int supplierId = _toInt(map['id']);
      double balance = await getSupplierBalance(supplierId);

      suppliers.add(
        Supplier.fromMap({
          'id': supplierId,
          'name': _toString(map['name']),
          'phone': _toString(map['phone']),
          'address': _toString(map['address']),
          'created_at': _toString(map['created_at']),
          'balance': balance,
        }),
      );
    }
    return suppliers;
  }

  // البحث في الموردين
  Future<List<Supplier>> searchSuppliers({String? searchTerm}) async {
    final db = await _dbHelper.database;

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

    List<Supplier> suppliers = [];
    for (var map in results) {
      int supplierId = _toInt(map['id']);
      double balance = await getSupplierBalance(supplierId);

      suppliers.add(
        Supplier.fromMap({
          'id': supplierId,
          'name': _toString(map['name']),
          'phone': _toString(map['phone']),
          'address': _toString(map['address']),
          'created_at': _toString(map['created_at']),
          'balance': balance,
        }),
      );
    }

    return suppliers;
  }

  // التحقق من وجود معاملات للمورد
  Future<bool> hasSupplierTransactions(int supplierId) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count 
      FROM purchase_invoices 
      WHERE supplier_id = ?
    ''',
      [supplierId],
    );

    if (result.isNotEmpty) {
      int count = _toInt(result.first['count']);
      return count > 0;
    }

    return false;
  }

  // إضافة مورد جديد (للتوافق مع الكود الحالي)
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  // إضافة مورد جديد مع الرصيد الافتتاحي
  Future<int> insertSupplierWithOpeningBalance(
    Supplier supplier,
    double openingBalance,
    String paymentType,
    String notes,
  ) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. إضافة المورد
      int supplierId = await txn.insert('suppliers', supplier.toMap());

      // 2. إذا كان هناك رصيد افتتاحي، إضافته
      if (openingBalance > 0) {
        final now = DateTime.now();
        await txn.insert('supplier_payments', {
          'supplier_id': supplierId,
          'payment_date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'payment_time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          'amount': openingBalance,
          'payment_type': paymentType,
          'notes': 'الرصيد الافتتاحي: $notes',
          'is_opening_balance': 1,
        });

        // 3. تسجيل معاملة الرصيد
        await _recordBalanceTransaction(
          txn: txn,
          supplierId: supplierId,
          description: 'الرصيد الافتتاحي',
          credit: openingBalance,
          balance: openingBalance,
        );
      }

      return supplierId;
    });
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

    await db.transaction((txn) async {
      // حذف السجلات المرتبطة أولاً
      await txn.delete(
        'supplier_payments',
        where: 'supplier_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'supplier_balance_transactions',
        where: 'supplier_id = ?',
        whereArgs: [id],
      );

      // ثم حذف المورد
      await txn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // حساب رصيد المورد (الطريقة المحسنة)
  Future<double> getSupplierBalance(int supplierId) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'DEBIT' THEN amount ELSE 0 END), 0) as total_debits,
        COALESCE(SUM(CASE WHEN transaction_type = 'CREDIT' THEN amount ELSE 0 END), 0) as total_credits
      FROM (
        -- من فواتير الشراء غير المدفوعة
        SELECT 'CREDIT' as transaction_type, remaining_amount as amount
        FROM purchase_invoices 
        WHERE supplier_id = ? AND remaining_amount > 0
        
        UNION ALL
        
        -- من الدفعات العادية
        SELECT 'DEBIT' as transaction_type, amount
        FROM supplier_payments 
        WHERE supplier_id = ? AND is_opening_balance = 0
        
        UNION ALL
        
        -- الرصيد الافتتاحي (يعتبر دين)
        SELECT 'CREDIT' as transaction_type, amount
        FROM supplier_payments 
        WHERE supplier_id = ? AND is_opening_balance = 1
      )
    ''',
      [supplierId, supplierId, supplierId],
    );

    if (result.isNotEmpty) {
      double totalCredits = _toDouble(result.first['total_credits']);
      double totalDebits = _toDouble(result.first['total_debits']);

      // الرصيد الإيجابي = نحن مدينون للمورد
      // الرصيد السلبي = المورد مدين لنا (نادر)
      return totalCredits - totalDebits;
    }

    return 0.0;
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

        double debtOnInvoice = _toDouble(invoice['remaining_amount']);
        double paidOnInvoice = _toDouble(invoice['paid_amount']);
        int invoiceId = _toInt(invoice['id']);

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

        // تسجيل معاملة الرصيد لهذه الدفعة
        await _recordBalanceTransaction(
          txn: txn,
          supplierId: supplierId,
          description: 'سداد فاتورة: ${invoice['invoice_number']} - $notes',
          debit: amountToPayForThisInvoice,
          balance: null, // سيتم حسابه تلقائياً
          invoiceId: invoiceId,
        );

        remainingPayment -= amountToPayForThisInvoice;
      }

      // إذا بقي مبلغ بعد سداد كل الفواتير (دفعة إضافية)
      if (remainingPayment > 0) {
        final now = DateTime.now();
        int paymentId = await txn.insert('supplier_payments', {
          'supplier_id': supplierId,
          'payment_date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'payment_time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          'amount': remainingPayment,
          'payment_type': 'نقدي',
          'notes': 'دفعة إضافية: $notes',
          'is_opening_balance': 0,
        });

        // تسجيل معاملة الرصيد للدفعة الإضافية
        await _recordBalanceTransaction(
          txn: txn,
          supplierId: supplierId,
          description: 'دفعة إضافية: $notes',
          debit: remainingPayment,
          balance: null,
          paymentId: paymentId,
        );
      }
    });
  }

  // إضافة دفعة للمورد (الطريقة الجديدة)
  Future<void> addSupplierPayment(SupplierPayment payment) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. إضافة الدفعة
      int paymentId = await txn.insert('supplier_payments', payment.toMap());

      // 2. تسجيل معاملة الرصيد
      await _recordBalanceTransaction(
        txn: txn,
        supplierId: payment.supplierId,
        description: payment.notes ?? 'دفعة للمورد',
        debit: payment.amount,
        balance: null,
        paymentId: paymentId,
      );
    });
  }

  // عند إضافة فاتورة شراء بالدين
  Future<void> recordSupplierPurchaseInvoice(
    int supplierId,
    int invoiceId,
    double totalAmount,
    double paidAmount,
  ) async {
    final db = await _dbHelper.database;
    double remainingAmount = totalAmount - paidAmount;

    if (remainingAmount > 0) {
      await db.transaction((txn) async {
        await _recordBalanceTransaction(
          txn: txn,
          supplierId: supplierId,
          description: 'فاتورة شراء جديدة',
          credit: remainingAmount,
          balance: null,
          invoiceId: invoiceId,
        );
      });
    }
  }

  // مساعدة: تسجيل معاملة الرصيد
  Future<void> _recordBalanceTransaction({
    required Transaction txn,
    required int supplierId,
    required String description,
    double debit = 0.0,
    double credit = 0.0,
    double? balance,
    int? invoiceId,
    int? paymentId,
  }) async {
    final now = DateTime.now();

    // حساب الرصيد الحالي
    double currentBalance = await _calculateSupplierBalanceForTransaction(
      txn,
      supplierId,
    );

    // تحديث الرصيد
    double newBalance = currentBalance - debit + credit;

    await txn.insert('supplier_balance_transactions', {
      'supplier_id': supplierId,
      'transaction_date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'transaction_time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': newBalance,
      'invoice_id': invoiceId,
      'payment_id': paymentId,
    });
  }

  // مساعدة: حساب الرصيد للمعاملة داخل transaction
  Future<double> _calculateSupplierBalanceForTransaction(
    Transaction txn,
    int supplierId,
  ) async {
    final result = await txn.rawQuery(
      '''
      SELECT balance 
      FROM supplier_balance_transactions 
      WHERE supplier_id = ? 
      ORDER BY id DESC 
      LIMIT 1
    ''',
      [supplierId],
    );

    if (result.isNotEmpty) {
      return _toDouble(result.first['balance']);
    }

    return 0.0;
  }

  // جلب سجل المعاملات للمورد
  Future<List<SupplierBalanceTransaction>> getSupplierTransactions(
    int supplierId, {
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'supplier_balance_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'transaction_date DESC, transaction_time DESC',
      limit: limit,
    );

    List<SupplierBalanceTransaction> transactions = [];
    for (var map in result) {
      transactions.add(
        SupplierBalanceTransaction.fromMap({
          'id': _toInt(map['id']),
          'supplier_id': _toInt(map['supplier_id']),
          'transaction_date': _toString(map['transaction_date']),
          'transaction_time': _toString(map['transaction_time']),
          'description': _toString(map['description']),
          'debit': _toDouble(map['debit']),
          'credit': _toDouble(map['credit']),
          'balance': _toDouble(map['balance']),
          'invoice_id':
              map['invoice_id'] != null ? _toInt(map['invoice_id']) : null,
          'payment_id':
              map['payment_id'] != null ? _toInt(map['payment_id']) : null,
          'created_at': _toString(map['created_at']),
        }),
      );
    }

    return transactions;
  }

  // جلب الدفعات للمورد
  Future<List<SupplierPayment>> getSupplierPayments(
    int supplierId, {
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'supplier_payments',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'payment_date DESC, payment_time DESC',
      limit: limit,
    );

    List<SupplierPayment> payments = [];
    for (var map in result) {
      payments.add(
        SupplierPayment.fromMap({
          'id': _toInt(map['id']),
          'supplier_id': _toInt(map['supplier_id']),
          'payment_date': _toString(map['payment_date']),
          'payment_time': _toString(map['payment_time']),
          'amount': _toDouble(map['amount']),
          'payment_type': _toString(map['payment_type']),
          'notes': _toString(map['notes']),
          'invoice_id':
              map['invoice_id'] != null ? _toInt(map['invoice_id']) : null,
          'is_opening_balance': _toInt(map['is_opening_balance']) == 1,
          'created_at': _toString(map['created_at']),
        }),
      );
    }

    return payments;
  }

  // جلب الموردين المدينين (الذين لدينا رصيد لهم)
  Future<List<Supplier>> getSuppliersWithBalance({
    bool positiveBalance = true,
  }) async {
    final suppliers = await getAllSuppliers();

    return suppliers.where((supplier) {
      if (positiveBalance) {
        return supplier.balance != null && supplier.balance! > 0;
      } else {
        return supplier.balance != null && supplier.balance! < 0;
      }
    }).toList();
  }

  // جلب إجمالي ديون الموردين
  Future<double> getTotalSuppliersBalance() async {
    final suppliers = await getAllSuppliers();

    double total = 0.0;
    for (var supplier in suppliers) {
      if (supplier.balance != null && supplier.balance! > 0) {
        total += supplier.balance!;
      }
    }

    return total;
  }

  // جلب عدد الموردين
  Future<int> getSuppliersCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM suppliers');

    if (result.isNotEmpty) {
      return _toInt(result.first['count']);
    }

    return 0;
  }
}
