// services/sales_invoice_service.dart
import 'package:pos_desktop/database/database_helper.dart';
import '../models/sales_invoice.dart';

class SalesInvoiceService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const int pageSize = 3;

  // الحصول على جميع فواتير المبيعات
  Future<List<SaleInvoice>> getAllSalesInvoices() async {
    final db = await _dbHelper.database;

    try {
      final invoices = await db.query(
        'sales_invoices',
        orderBy: 'created_at DESC',
      );

      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);
        final items = await getInvoiceItems(invoice.id!);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            paidAmount: invoice.paidAmount,
            remainingAmount: invoice.remainingAmount,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            paymentType: invoice.paymentType,
            paymentStatus: invoice.paymentStatus,
            originalTotal: invoice.originalTotal,
            notes: invoice.notes,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في تحميل فواتير المبيعات: $e');
    }
  }

  // باقي الدوال تبقى كما هي مع تحديث استخدام الحقول الجديدة
  Future<List<SaleInvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await _dbHelper.database;
    try {
      final items = await db.query(
        'sales_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );
      return items.map((itemMap) => SaleInvoiceItem.fromMap(itemMap)).toList();
    } catch (e) {
      return [];
    }
  }

  // الحصول على فاتورة بواسطة ID
  Future<SaleInvoice?> getInvoiceById(int id) async {
    final db = await _dbHelper.database;
    try {
      final invoices = await db.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (invoices.isEmpty) return null;

      final invoice = SaleInvoice.fromMap(invoices.first);
      final items = await getInvoiceItems(invoice.id!);

      return SaleInvoice(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        date: invoice.date,
        time: invoice.time,
        total: invoice.total,
        paidAmount: invoice.paidAmount,
        remainingAmount: invoice.remainingAmount,
        cashier: invoice.cashier,
        customerName: invoice.customerName,
        paymentMethod: invoice.paymentMethod,
        paymentType: invoice.paymentType,
        paymentStatus: invoice.paymentStatus,
        originalTotal: invoice.originalTotal,
        notes: invoice.notes,
        createdAt: invoice.createdAt,
        items: items,
      );
    } catch (e) {
      return null;
    }
  }

  // البحث في فواتير المبيعات
  Future<List<SaleInvoice>> searchInvoices(
    String searchTerm, {
    String? startDate,
    String? endDate,
  }) async {
    final db = await _dbHelper.database;
    try {
      // تحديث شرط البحث ليشمل اسم العميل
      String whereClause =
          '(invoice_number LIKE ? OR cashier LIKE ? OR customer_name LIKE ?)';
      List<dynamic> whereArgs = [
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
      ];

      if (startDate != null && endDate != null) {
        whereClause += ' AND date BETWEEN ? AND ?';
        whereArgs.addAll([startDate, endDate]);
      } else if (startDate != null) {
        whereClause += ' AND date >= ?';
        whereArgs.add(startDate);
      } else if (endDate != null) {
        whereClause += ' AND date <= ?';
        whereArgs.add(endDate);
      }

      final invoices = await db.rawQuery('''
      SELECT * FROM sales_invoices 
      WHERE $whereClause
      ORDER BY created_at DESC
      LIMIT 100
    ''', whereArgs);

      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);
        final items = await getInvoiceItems(invoice.id!);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            paidAmount: invoice.paidAmount,
            remainingAmount: invoice.remainingAmount,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            paymentType: invoice.paymentType,
            paymentStatus: invoice.paymentStatus,
            originalTotal: invoice.originalTotal,
            notes: invoice.notes,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في البحث: $e');
    }
  }

  // الحصول على إحصائيات المبيعات
  Future<Map<String, dynamic>> getSalesStatistics() async {
    final db = await _dbHelper.database;

    try {
      // إجمالي عدد الفواتير
      final totalInvoicesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_invoices',
      );
      final totalInvoices = totalInvoicesResult.first['count'] as int? ?? 0;

      // إجمالي المبيعات
      final totalSalesResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices',
      );
      final totalSales =
          (totalSalesResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      // متوسط قيمة الفاتورة
      final averageInvoice =
          totalInvoices > 0 ? totalSales / totalInvoices : 0.0;

      // المبيعات اليوم
      final today = DateTime.now();
      final todayFormatted =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final todaySalesResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices WHERE date = ?',
        [todayFormatted],
      );
      final todaySales =
          (todaySalesResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      return {
        'totalInvoices': totalInvoices,
        'totalSales': totalSales,
        'averageInvoice': averageInvoice,
        'todaySales': todaySales,
      };
    } catch (e) {
      return {
        'totalInvoices': 0,
        'totalSales': 0.0,
        'averageInvoice': 0.0,
        'todaySales': 0.0,
      };
    }
  }

  // حذف فاتورة
  Future<bool> deleteInvoice(int id) async {
    final db = await _dbHelper.database;

    try {
      final result = await db.delete(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [id],
      );

      return result > 0;
    } catch (e) {
      throw Exception('فشل في حذف الفاتورة: $e');
    }
  }

  // الحصول على فواتير مع التحميل التدريجي
  Future<List<SaleInvoice>> getSalesInvoicesPaginated({
    required int page,
    int pageSize = pageSize,
    String? startDate,
    String? endDate,
    String? searchTerm,
  }) async {
    final db = await _dbHelper.database;

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      // إضافة شرط البحث إذا كان موجود
      if (searchTerm != null && searchTerm.isNotEmpty) {
        whereClause =
            '(invoice_number LIKE ? OR cashier LIKE ? OR customer_name LIKE ?)';
        whereArgs.addAll(['%$searchTerm%', '%$searchTerm%', '%$searchTerm%']);
      }

      if (startDate != null && endDate != null) {
        whereClause +=
            whereClause.isNotEmpty
                ? ' AND date BETWEEN ? AND ?'
                : 'date BETWEEN ? AND ?';
        whereArgs.addAll([startDate, endDate]);
      } else if (startDate != null) {
        whereClause += whereClause.isNotEmpty ? ' AND date >= ?' : 'date >= ?';
        whereArgs.add(startDate);
      } else if (endDate != null) {
        whereClause += whereClause.isNotEmpty ? ' AND date <= ?' : 'date <= ?';
        whereArgs.add(endDate);
      }

      final offset = (page - 1) * pageSize;

      final query = '''
      SELECT * FROM sales_invoices 
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    ''';

      whereArgs.addAll([pageSize, offset]);

      final invoices = await db.rawQuery(query, whereArgs);

      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);
        final items = await getInvoiceItems(invoice.id!);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            paidAmount: invoice.paidAmount,
            remainingAmount: invoice.remainingAmount,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            paymentType: invoice.paymentType,
            paymentStatus: invoice.paymentStatus,
            originalTotal: invoice.originalTotal,
            notes: invoice.notes,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في تحميل فواتير المبيعات: $e');
    }
  }

  Future<SaleInvoice> createInvoice({
    required String invoiceNumber,
    required String date,
    required String time,
    required List<SaleInvoiceItem> items,
    required double total,
    required String cashier,
    String? customerName,
    int? customerId,
    String paymentMethod = 'نقدي',
    double paidAmount = 0.0,
    double remainingAmount = 0.0,
  }) async {
    final db = await _dbHelper.database;

    // تحديد نوع الدفع وحالة السداد
    final String paymentType = (remainingAmount > 0) ? 'آجل' : 'نقدي';
    final String paymentStatus = _determinePaymentStatus(
      paidAmount,
      total,
      remainingAmount,
    );

    String? finalCustomerName = customerName;

    // إذا كان في customerId، جلب اسم العميل من الداتابيز
    if (customerId != null && customerId > 0 && customerName == null) {
      try {
        final customer = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customerId],
        );
        if (customer.isNotEmpty) {
          finalCustomerName = customer.first['name'] as String?;
        }
      } catch (e) {
        print('❌ خطأ في جلب اسم العميل: $e');
      }
    }

    await db.transaction((txn) async {
      // إدخال الفاتورة الرئيسية
      final Map<String, dynamic> invoiceData = {
        'invoice_number': invoiceNumber,
        'date': date,
        'time': time,
        'total': total,
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'cashier': cashier,
        'customer_id': customerId,
        'customer_name': finalCustomerName,
        'payment_method': paymentMethod,
        'payment_type': paymentType,
        'payment_status': paymentStatus,
        'original_total': total,
        'created_at': DateTime.now().toIso8601String(),
      };

      // نظف البيانات - إذا customer_name بيكون null، امسحه من البيانات
      invoiceData.removeWhere((key, value) => value == null);

      final invoiceId = await txn.insert('sales_invoices', invoiceData);

      // إدخال عناصر الفاتورة وتحديث المخزون
      for (final item in items) {
        // 1. إدخال عنصر الفاتورة مع unit_quantity و unit_name
        await txn.insert('sales_invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'unit_quantity': item.unitQuantity, // ⬅️ عدد الحبات في الوحدة
          'unit_name': item.unitName, // ⬅️ اسم الحزمة (كرتونة، علبة، إلخ)
        });

        // 2. تحديث المخزون
        final totalQuantity = item.quantity * item.unitQuantity;
        final result = await txn.rawUpdate(
          '''
    UPDATE products 
    SET stock = stock - ?, 
        updated_at = CURRENT_TIMESTAMP 
    WHERE id = ? AND stock >= ?
  ''',
          [totalQuantity, item.productId, totalQuantity],
        );

        if (result == 0) {
          throw Exception('المخزون غير كافي للمنتج ${item.productName}');
        }
      }
    });

    // الحصول على الفاتورة المضافة
    final results = await db.query(
      'sales_invoices',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
    );

    if (results.isEmpty) {
      throw Exception('لم يتم العثور على الفاتورة بعد الإدخال');
    }

    final savedInvoice = results.first;
    final invoice = SaleInvoice.fromMap(savedInvoice);
    final itemsFromDb = await getInvoiceItems(invoice.id!);

    return SaleInvoice(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      date: invoice.date,
      time: invoice.time,
      total: invoice.total,
      paidAmount: invoice.paidAmount,
      remainingAmount: invoice.remainingAmount,
      cashier: invoice.cashier,
      customerName: invoice.customerName,
      paymentMethod: invoice.paymentMethod,
      paymentType: invoice.paymentType,
      paymentStatus: invoice.paymentStatus,
      originalTotal: invoice.originalTotal,
      notes: invoice.notes,
      createdAt: invoice.createdAt,
      items: itemsFromDb,
    );
  }

  String _determinePaymentStatus(
    double paidAmount,
    double total,
    double remainingAmount,
  ) {
    String status;

    if (paidAmount == 0) {
      status = 'غير مدفوع';
    } else if (remainingAmount > 0) {
      status = 'جزئي';
    } else {
      status = 'مدفوع';
    }

    return status;
  }

  // الحصول على عدد الفواتير الكلي للفلترة
  Future<int> getInvoicesCount({
    String? startDate,
    String? endDate,
    String? searchTerm, // <-- أضف هذا الباراميتر
  }) async {
    final db = await _dbHelper.database;

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      // إضافة شرط البحث إذا كان موجود
      if (searchTerm != null && searchTerm.isNotEmpty) {
        whereClause =
            '(invoice_number LIKE ? OR cashier LIKE ? OR customer_name LIKE ?)';
        whereArgs.addAll(['%$searchTerm%', '%$searchTerm%', '%$searchTerm%']);
      }

      if (startDate != null && endDate != null) {
        whereClause +=
            whereClause.isNotEmpty
                ? ' AND date BETWEEN ? AND ?'
                : 'date BETWEEN ? AND ?';
        whereArgs.addAll([startDate, endDate]);
      } else if (startDate != null) {
        whereClause += whereClause.isNotEmpty ? ' AND date >= ?' : 'date >= ?';
        whereArgs.add(startDate);
      } else if (endDate != null) {
        whereClause += whereClause.isNotEmpty ? ' AND date <= ?' : 'date <= ?';
        whereArgs.add(endDate);
      }

      final countResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sales_invoices 
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
    ''', whereArgs);

      return countResult.first['count'] as int? ?? 0;
    } catch (e) {
      throw Exception('فشل في حساب عدد الفواتير: $e');
    }
  }

  // الحصول على التواريخ المتاحة للفلترة
  Future<Map<String, dynamic>> getAvailableDates() async {
    final db = await _dbHelper.database;

    try {
      final firstDateResult = await db.rawQuery(
        'SELECT date FROM sales_invoices ORDER BY date ASC LIMIT 1',
      );
      final lastDateResult = await db.rawQuery(
        'SELECT date FROM sales_invoices ORDER BY date DESC LIMIT 1',
      );

      final firstDate =
          firstDateResult.isNotEmpty
              ? firstDateResult.first['date'] as String?
              : null;
      final lastDate =
          lastDateResult.isNotEmpty
              ? lastDateResult.first['date'] as String?
              : null;

      return {'firstDate': firstDate, 'lastDate': lastDate};
    } catch (e) {
      return {'firstDate': null, 'lastDate': null};
    }
  }

  // في sales_invoice_service.dart
  Future<void> updateInvoicePaymentStatus(int invoiceId) async {
    final db = await _dbHelper.database;

    try {
      // جلب بيانات الفاتورة الحالية
      final invoices = await db.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (invoices.isEmpty) return;

      final invoice = invoices.first;
      final double total = (invoice['total'] as num).toDouble();
      final double paidAmount =
          (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final double remainingAmount =
          (invoice['remaining_amount'] as num?)?.toDouble() ?? 0.0;

      // تحديد الحالة الجديدة
      String newPaymentStatus;
      String newPaymentType;

      if (remainingAmount <= 0 && paidAmount >= total) {
        newPaymentStatus = 'مدفوع';
        newPaymentType = 'نقدي';
      } else if (remainingAmount > 0 && paidAmount > 0) {
        newPaymentStatus = 'جزئي';
        newPaymentType = 'آجل';
      } else {
        newPaymentStatus = 'غير مدفوع';
        newPaymentType = 'آجل';
      }

      // تحديث الفاتورة
      await db.update(
        'sales_invoices',
        {
          'payment_status': newPaymentStatus,
          'payment_type': newPaymentType,
          'paid_amount': paidAmount,
          'remaining_amount': remainingAmount,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    } catch (e) {
      throw Exception('فشل في تحديث حالة الفاتورة: $e');
    }
  }

  Future<String> getCustomerNameById(int? customerId) {
    if (customerId == null) return Future.value('عميل نقدي');

    return _dbHelper.database.then((db) async {
      try {
        final customer = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customerId],
        );
        if (customer.isNotEmpty) {
          return customer.first['name'] as String;
        } else {
          return 'عميل نقدي';
        }
      } catch (e) {
        return 'عميل نقدي';
      }
    });
  }

  //ارجاع فاتورة
  Future<bool> returnInvoice(int invoiceId) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        // 1. جلب بيانات الفاتورة والعناصر
        final invoice = await txn.query(
          'sales_invoices',
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        if (invoice.isEmpty) {
          throw Exception('الفاتورة غير موجودة');
        }

        final items = await txn.query(
          'sales_invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // 2. إرجاع المخزون للمنتجات
        for (final item in items) {
          final productId = item['product_id'] as int;
          final quantity = item['quantity'] as double;
          final unitQuantity = item['unit_quantity'] as double? ?? 1.0;

          final totalQuantity = quantity * unitQuantity;

          await txn.rawUpdate(
            '''
          UPDATE products 
          SET stock = stock + ?, 
              updated_at = CURRENT_TIMESTAMP 
          WHERE id = ?
          ''',
            [totalQuantity, productId],
          );
        }

        // 3. إذا كان هناك عميل وديون، تحديث الديون
        final invoiceData = invoice.first;
        final customerId = invoiceData['customer_id'] as int?;
        final remainingAmount =
            (invoiceData['remaining_amount'] as num?)?.toDouble() ?? 0.0;

        if (customerId != null && remainingAmount > 0) {
          // هنا يمكنك إضافة منطق تحديث ديون العميل إذا كان لديك جدول للديون
        }

        // 4. حذف سجلات السداد المرتبطة بالفاتورة
        await txn.delete(
          'payment_records',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // 5. حذف عناصر الفاتورة
        await txn.delete(
          'sales_invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // 6. حذف الفاتورة الرئيسية
        await txn.delete(
          'sales_invoices',
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      });

      return true;
    } catch (e) {
      throw Exception('فشل في إرجاع الفاتورة: $e');
    }
  }

  // في sales_invoice_service.dart - أضف هذه الدالة
  Future<List<SaleInvoice>> getCustomerStatement({
    required int customerId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await _dbHelper.database;

    try {
      final invoices = await db.rawQuery(
        '''
      SELECT * FROM sales_invoices 
      WHERE customer_id = ? 
        AND date BETWEEN ? AND ?
      ORDER BY date DESC, time DESC
    ''',
        [customerId, startDate, endDate],
      );

      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);
        final items = await getInvoiceItems(invoice.id!);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            paidAmount: invoice.paidAmount,
            remainingAmount: invoice.remainingAmount,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            paymentType: invoice.paymentType,
            paymentStatus: invoice.paymentStatus,
            originalTotal: invoice.originalTotal,
            notes: invoice.notes,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في تحميل كشف حساب العميل: $e');
    }
  }
}
