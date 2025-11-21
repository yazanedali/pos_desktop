// services/sales_invoice_service.dart
import 'package:pos_desktop/database/database_helper.dart';
import '../models/sales_invoice.dart';

class SalesInvoiceService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const int pageSize = 15;

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
      String whereClause = '(invoice_number LIKE ? OR cashier LIKE ?)';
      List<dynamic> whereArgs = ['%$searchTerm%', '%$searchTerm%'];

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
  }) async {
    final db = await _dbHelper.database;

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause = 'date BETWEEN ? AND ?';
        whereArgs.addAll([startDate, endDate]);
      } else if (startDate != null) {
        whereClause = 'date >= ?';
        whereArgs.add(startDate);
      } else if (endDate != null) {
        whereClause = 'date <= ?';
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

  // دالة لإنشاء فاتورة جديدة
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

    // تحقق من أن القيم متسقة
    assert(
      (paidAmount + remainingAmount - total).abs() < 0.01,
      'القيم غير متسقة: paidAmount + remainingAmount != total',
    );

    // تحديد نوع الدفع وحالة السداد
    final String paymentType = (remainingAmount > 0) ? 'آجل' : 'نقدي';
    final String paymentStatus = _determinePaymentStatus(
      paidAmount,
      total,
      remainingAmount,
    );

    print('🧾 إنشاء فاتورة جديدة:');
    print('   - رقم الفاتورة: $invoiceNumber');
    print('   - الإجمالي: $total');
    print('   - المدفوع: $paidAmount');
    print('   - المتبقي: $remainingAmount');
    print('   - نوع الدفع المحدد: $paymentType');
    print('   - حالة السداد المحددة: $paymentStatus');

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
        'customer_name': customerName,
        'payment_method': paymentMethod,
        'payment_type': paymentType,
        'payment_status': paymentStatus,
        'original_total': total,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('💾 حفظ بيانات الفاتورة في DB:');
      print('   - payment_type: ${invoiceData['payment_type']}');
      print('   - payment_status: ${invoiceData['payment_status']}');

      final invoiceId = await txn.insert('sales_invoices', invoiceData);

      // إدخال عناصر الفاتورة
      for (final item in items) {
        await txn.insert('sales_invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        });
      }
    });

    // الحصول على الفاتورة المضافة والتحقق من القيم
    final results = await db.query(
      'sales_invoices',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
    );

    if (results.isEmpty) {
      throw Exception('لم يتم العثور على الفاتورة بعد الإدخال');
    }

    final savedInvoice = results.first;
    print('✅ الفاتورة محفوظة في DB:');
    print('   - payment_type: ${savedInvoice['payment_type']}');
    print('   - payment_status: ${savedInvoice['payment_status']}');
    print('   - paid_amount: ${savedInvoice['paid_amount']}');
    print('   - remaining_amount: ${savedInvoice['remaining_amount']}');

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
    print('🔍 تحديد حالة السداد:');
    print('   - المدفوع: $paidAmount');
    print('   - الإجمالي: $total');
    print('   - المتبقي: $remainingAmount');

    String status;

    if (paidAmount == 0) {
      status = 'غير مدفوع';
    } else if (remainingAmount > 0) {
      status = 'جزئي';
    } else {
      status = 'مدفوع';
    }

    print('   - الحالة المحددة: $status');
    return status;
  }

  // الحصول على عدد الفواتير الكلي للفلترة
  Future<int> getInvoicesCount({String? startDate, String? endDate}) async {
    final db = await _dbHelper.database;

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause = 'date BETWEEN ? AND ?';
        whereArgs.addAll([startDate, endDate]);
      } else if (startDate != null) {
        whereClause = 'date >= ?';
        whereArgs.add(startDate);
      } else if (endDate != null) {
        whereClause = 'date <= ?';
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

      print('🔄 تم تحديث فاتورة $invoiceId:');
      print('   - الحالة: $newPaymentStatus');
      print('   - النوع: $newPaymentType');
      print('   - المدفوع: $paidAmount');
      print('   - المتبقي: $remainingAmount');
    } catch (e) {
      print('❌ خطأ في تحديث حالة الفاتورة: $e');
      throw Exception('فشل في تحديث حالة الفاتورة: $e');
    }
  }
}
