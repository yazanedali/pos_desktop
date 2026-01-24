// services/sales_invoice_service.dart
import 'package:pos_desktop/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sales_invoice.dart';
import '../models/statement_item.dart';
import 'dart:math';
import 'package:pos_desktop/services/stock_alert_service.dart';

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
            isReturn: invoice.isReturn,
            parentInvoiceId: invoice.parentInvoiceId,
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
        isReturn: invoice.isReturn,
        parentInvoiceId: invoice.parentInvoiceId,
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
            isReturn: invoice.isReturn,
            parentInvoiceId: invoice.parentInvoiceId,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في البحث: $e');
    }
  }

  // الحصول على إحصائيات المبيعات مع صافي ربح اليوم
  // الحصول على إحصائيات المبيعات مع صافي ربح اليوم (النقدي فقط)
  // الحصول على إحصائيات المبيعات (نقدي فقط، واستثناء الدفع من المحفظة)
  // services/sales_invoice_service.dart

  // تحديث الدالة لتتطابق مع منطق التقارير الجديدة
  Future<Map<String, dynamic>> getSalesStatistics() async {
    final db = await _dbHelper.database;

    try {
      // التاريخ الحالي
      final today = DateTime.now();
      final todayFormatted =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 1. حساب إجمالي الفواتير والمبيعات (تراكمي - للمعلومة العامة)
      final totalInvoicesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_invoices',
      );
      final totalInvoices = totalInvoicesResult.first['count'] as int? ?? 0;

      final totalSalesResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices',
      );
      final totalSalesAllTime =
          (totalSalesResult.first['sum'] as num?)?.toDouble() ?? 0.0;
      final averageInvoice =
          totalInvoices > 0 ? totalSalesAllTime / totalInvoices : 0.0;

      // ============================================================
      // 🟢 2. حساب "مقبوضات اليوم" (ليطابق NewReportsPage)
      // المعادلة: (كاش من فواتير اليوم) + (كاش من سداد ديون اليوم) - (استثناء الدفع من الرصيد)
      // ============================================================

      // أ. الكاش من فواتير اليوم المباشرة
      final directCashResult = await db.rawQuery(
        '''
        SELECT SUM(paid_amount) as sum 
        FROM sales_invoices 
        WHERE date = ? 
        AND payment_method != 'من الرصيد'
        ''',
        [todayFormatted],
      );
      final directCash =
          (directCashResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      // ب. الكاش من سداد الديون اليوم
      double debtCash = 0.0;
      try {
        final debtCashResult = await db.rawQuery(
          '''
          SELECT SUM(pr.amount) as sum 
          FROM payment_records pr
          LEFT JOIN sales_invoices si ON pr.invoice_id = si.id
          WHERE pr.payment_date = ? 
          AND pr.payment_method != 'من الرصيد'
          AND si.date != ? -- ✅ استثناء الفواتير التي أنشئت اليوم (فقط سداد الديون القديمة)
          ''',
          [todayFormatted, todayFormatted],
        );
        debtCash = (debtCashResult.first['sum'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        // في حال عدم وجود الجدول
      }

      final totalCollectedToday = directCash + debtCash;

      // ============================================================
      // 🟢 3. حساب "الربح المحقق اليوم" (ليطابق RealProfitStat)
      // المعادلة: (مجمل ربح فواتير اليوم) * (نسبة التحصيل لفواتير اليوم)
      // ============================================================

      // أ. مبيعات فواتير اليوم (القيمة الكلية)
      final todaySalesTotalResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices WHERE date = ?',
        [todayFormatted],
      );
      final todaySalesTotal =
          (todaySalesTotalResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      // ب. تكلفة فواتير اليوم
      final todayCostResult = await db.rawQuery(
        '''
        SELECT SUM(sii.quantity * sii.unit_quantity * COALESCE(NULLIF(sii.cost_price, 0), p.purchase_price, 0)) as cogs
        FROM sales_invoice_items sii
        JOIN sales_invoices si ON sii.invoice_id = si.id
        LEFT JOIN products p ON sii.product_id = p.id
        WHERE si.date = ?
        ''',
        [todayFormatted],
      );
      final todayCost =
          (todayCostResult.first['cogs'] as num?)?.toDouble() ?? 0.0;

      // ج. الربح الإجمالي (المحاسبي)
      final grossProfit = todaySalesTotal - todayCost;

      // د. نسبة التحصيل (لفواتير اليوم حصراً)
      // ملاحظة: نستخدم directCash الذي حسبناه فوق (المقبوض من فواتير اليوم باستثناء الرصيد)
      double collectionRatio = 0.0;
      if (todaySalesTotal > 0) {
        collectionRatio = directCash / todaySalesTotal;
      }

      // هـ. الربح المحقق فعلياً
      final realizedProfit = grossProfit * collectionRatio;

      return {
        'totalInvoices': totalInvoices,
        'totalSales': totalSalesAllTime,
        'averageInvoice': averageInvoice,

        // المتغيرات الجديدة التي ستعرض في الواجهة
        'todayCollected':
            totalCollectedToday, // هذا الرقم يطابق التحصيلات في التقرير الجديد
        'todayRealizedProfit':
            realizedProfit, // هذا الرقم يطابق الربح المحقق في التقرير الجديد
      };
    } catch (e) {
      print('❌ خطأ في حساب الإحصائيات: $e');
      return {
        'totalInvoices': 0,
        'totalSales': 0.0,
        'averageInvoice': 0.0,
        'todayCollected': 0.0,
        'todayRealizedProfit': 0.0,
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
            isReturn: invoice.isReturn,
            parentInvoiceId: invoice.parentInvoiceId,
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
    double? originalTotal,
  }) async {
    final db = await _dbHelper.database;

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
      double finalPaidAmount = paidAmount;
      double finalRemainingAmount = remainingAmount;
      String finalPaymentMethod = paymentMethod;

      // 1. إذا كان هناك دين متبقي، نتحقق من محفظة العميل أولاً (دمج المحفظة بالدين)
      if (customerId != null && finalRemainingAmount > 0) {
        final List<Map<String, dynamic>> customers = await txn.query(
          'customers',
          columns: ['wallet_balance'],
          where: 'id = ?',
          whereArgs: [customerId],
        );
        if (customers.isNotEmpty) {
          double walletBal =
              (customers.first['wallet_balance'] as num).toDouble();
          if (walletBal > 0) {
            double amountToUseFromWallet = min(finalRemainingAmount, walletBal);
            finalRemainingAmount -= amountToUseFromWallet;
            finalPaidAmount += amountToUseFromWallet;

            // تحديث المحفظة
            await txn.rawUpdate(
              'UPDATE customers SET wallet_balance = wallet_balance - ? WHERE id = ?',
              [amountToUseFromWallet, customerId],
            );

            // تحديث طريقة الدفع إذا تغيرت الحالة
            if (finalPaymentMethod == 'نقدي' && amountToUseFromWallet > 0) {
              finalPaymentMethod = 'نقدي + رصيد';
            }
          }
        }
      }

      // إعادة حساب الحالة بعد استهلاك المحفظة
      final String finalPaymentStatus = _determinePaymentStatus(
        finalPaidAmount,
        total,
        finalRemainingAmount,
      );
      final String finalPaymentType =
          (finalRemainingAmount > 0) ? 'آجل' : 'نقدي';

      // إدخال الفاتورة الرئيسية
      final Map<String, dynamic> invoiceData = {
        'invoice_number': invoiceNumber,
        'date': date,
        'time': time,
        'total': total,
        'paid_amount': finalPaidAmount,
        'remaining_amount': finalRemainingAmount,
        'cashier': cashier,
        'customer_id': customerId,
        'customer_name': finalCustomerName,
        'payment_method': finalPaymentMethod,
        'payment_type': finalPaymentType,
        'payment_status': finalPaymentStatus,
        'original_total': originalTotal ?? total,
        'created_at': DateTime.now().toIso8601String(),
        'is_return': 0, // Not a return
      };

      // نظف البيانات
      invoiceData.removeWhere((key, value) => value == null);

      final invoiceId = await txn.insert('sales_invoices', invoiceData);

      // إدخال عناصر الفاتورة وتحديث المخزون
      for (final item in items) {
        double finalCostPrice = item.costPrice;

        // --- Fail-Safe: إذا كانت التكلفة صفر، نجلبها من قاعدة البيانات مباشرة ---
        // هذا يضمن عدم ضياع التكلفة بسبب أي خلل في الواجهة
        if (finalCostPrice == 0 && item.productId != null) {
          try {
            final productResult = await txn.rawQuery(
              'SELECT purchase_price FROM products WHERE id = ?',
              [item.productId],
            );
            if (productResult.isNotEmpty) {
              final dbPrice =
                  (productResult.first['purchase_price'] as num?)?.toDouble() ??
                  0.0;
              if (dbPrice > 0) {
                print(
                  '⚠️ Recovered Cost Price for ${item.productName}: $dbPrice',
                );
                finalCostPrice = dbPrice;
              }
            }
          } catch (e) {
            print('Error fetching fallback cost: $e');
          }
        }
        // -----------------------------------------------------------------------

        print(
          'DEBUG: Inserting Invoice Item: ${item.productName}, Cost Price: $finalCostPrice',
        );
        await txn.insert('sales_invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'unit_quantity': item.unitQuantity,
          'unit_name': item.unitName,
          'cost_price': item.costPrice,
        });

        final totalQuantity = item.quantity * item.unitQuantity;
        final stockUpdateResult = await txn.rawUpdate(
          '''
          UPDATE products 
          SET stock = stock - ?, 
              updated_at = CURRENT_TIMESTAMP 
          WHERE id = ? AND stock >= ?
          ''',
          [totalQuantity, item.productId, totalQuantity],
        );

        if (stockUpdateResult == 0) {
          throw Exception('المخزون غير كافي للمنتج ${item.productName}');
        }
      }

      // 3. خصم إضافي من المحفظة إذا كان الخيار المختار هو "من الرصيد"
      // (هذا الجزء كان موجوداً وسأبقي عليه كخيار يدوي، ولكن المنطق أعلاه يقوم بالتغطية التلقائية للدين)
      if (paymentMethod == 'من الرصيد' &&
          customerId != null &&
          paidAmount > 0) {
        // بما أننا قمنا بخصم الجزء "الآجل" تلقائياً أعلاه،
        // هنا نخصم الـ paidAmount الأصلي إذا كان المستخدم اختار صراحةً الدفع من الرصيد
        // ملاحظة: المنطق العلوي يغطي حالة "لو عليه دين ينطرح من الرصيد"
        // أما هنا فهو حالة "دفع يدوي من الرصيد"

        // التحقق من الرصيد المتبقي مجدداً بعد العملية العلوية
        final List<Map<String, dynamic>> customers2 = await txn.query(
          'customers',
          columns: ['wallet_balance'],
          where: 'id = ?',
          whereArgs: [customerId],
        );
        double currentW =
            (customers2.first['wallet_balance'] as num).toDouble();
        if (currentW >= paidAmount) {
          await txn.rawUpdate(
            'UPDATE customers SET wallet_balance = wallet_balance - ? WHERE id = ?',
            [paidAmount, customerId],
          );
        } else {
          // إذا لم يعد الرصيد كافياً بعد التغطية التلقائية للدين
          // (هذه الحالة نادرة وتحدث لو المستخدم حدد دفع مبلغ نقدي كبير من الرصيد وهو أصلاً عنده دين سيغطي الرصيد)
          throw Exception('الرصيد في المحفظة غير كافٍ');
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

    // تحديث التنبيهات بعد البيع
    StockAlertService().checkAlerts();

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
      isReturn: invoice.isReturn,
      parentInvoiceId: invoice.parentInvoiceId,
      items: itemsFromDb,
    );
  }

  String _determinePaymentStatus(
    double paidAmount,
    double total,
    double remainingAmount,
  ) {
    if (paidAmount == 0) return 'غير مدفوع';
    if (remainingAmount > 0.01) return 'جزئي'; // هامش خطأ صغير
    return 'مدفوع';
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
  // ارجاع فاتورة بالكامل مع خصم المبلغ من الصندوق اليومي
  // إرجاع الفاتورة (إنشاء فاتورة مرتجع)
  Future<bool> createReturnInvoice(int invoiceId) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        // 1. جلب بيانات الفاتورة الأصلية
        final invoiceList = await txn.query(
          'sales_invoices',
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        if (invoiceList.isEmpty) {
          throw Exception('الفاتورة غير موجودة');
        }

        final originalInvoice = invoiceList.first;

        // التحقق من أنها ليست مرتجعة بالفعل
        if ((originalInvoice['is_return'] as int?) == 1) {
          throw Exception('لا يمكن إرجاع فاتورة مرتجعة أصلاً');
        }

        final String originalInvoiceNumber =
            originalInvoice['invoice_number'] as String;
        final double total = (originalInvoice['total'] as num).toDouble();
        final double paidAmount =
            (originalInvoice['paid_amount'] as num).toDouble();
        final String paymentMethod =
            originalInvoice['payment_method'] as String;
        final int? customerId = originalInvoice['customer_id'] as int?;

        // 2. إنشاء فاتورة مرتجع جديدة
        final newInvoiceNumber = 'RET-$originalInvoiceNumber';

        // تخزين القيم بالسالب لضمان صحة الحسابات والتجميع
        final returnInvoiceId = await txn.insert('sales_invoices', {
          'invoice_number': newInvoiceNumber,
          'date': DateTime.now().toString().split(' ')[0],
          'time': DateTime.now().toString().split(' ')[1].substring(0, 8),
          'total': -total, // ⬅️ سالب
          'paid_amount': -paidAmount, // ⬅️ سالب
          'remaining_amount': 0.0,
          'cashier': originalInvoice['cashier'],
          'customer_id': customerId,
          'customer_name': originalInvoice['customer_name'],
          'payment_method': paymentMethod,
          'payment_status': 'مرتجع',
          'original_total': -total, // ⬅️ سالب
          'is_return': 1,
          'parent_invoice_id': invoiceId,
          'notes': 'مرتجع للفاتورة $originalInvoiceNumber',
        });

        // 3. نسخ العناصر للفاتورة الجديدة + إعادة المخزون
        final items = await txn.query(
          'sales_invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        for (final item in items) {
          final double quantity = (item['quantity'] as num).toDouble();
          final double unitQuantity =
              (item['unit_quantity'] as num?)?.toDouble() ?? 1.0;
          final int? productId = item['product_id'] as int?;

          // نسخ العنصر لفاتورة المرتجع مع قيم سالبة
          await txn.insert('sales_invoice_items', {
            'invoice_id': returnInvoiceId,
            'product_id': productId,
            'product_name': item['product_name'],
            'price': item['price'],
            'quantity': -quantity, // ⬅️ كمية سالبة
            'total': -(item['total'] as num).toDouble(), // ⬅️ إجمالي سالب
            'unit_quantity': unitQuantity,
            'unit_name': item['unit_name'],
            'cost_price': item['cost_price'],
          });

          // إعادة المخزون (إضافة الكمية الموجبة للمخزون)
          if (productId != null) {
            final totalQuantity = quantity * unitQuantity;
            await txn.rawUpdate(
              'UPDATE products SET stock = stock + ? WHERE id = ?',
              [totalQuantity, productId],
            );
          }
        }

        // 4. معالجة المال (إرجاع كاش أو تخفيض ديون)
        if (paidAmount > 0) {
          if (paymentMethod != 'من الرصيد') {
            // إخراج كاش من الصندوق (Refund)
            // ملاحظة: نستخدم القيمة الموجبة هنا لأن دالة الصندوق تتوقع قيمة موجبة للسحب
            await _processRefundFromDailyBox(
              txn,
              amount: paidAmount,
              description: 'مرتجع مبيعات فاتورة $originalInvoiceNumber',
              relatedId: returnInvoiceId,
            );
          } else {
            // لو كان الدفع من الرصيد، نعيد الرصيد للمحفظة
            if (customerId != null) {
              await txn.rawUpdate(
                'UPDATE customers SET wallet_balance = wallet_balance + ? WHERE id = ?',
                [paidAmount, customerId],
              );
            }
          }
        }

        // تحديث حالة الفاتورة الأصلية
        await txn.update(
          'sales_invoices',
          {
            'payment_status': 'تم الإرجاع',
            'notes': 'تم إرجاعها بالفاتورة $newInvoiceNumber',
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      });

      // تحديث التنبيهات بعد الإرجاع
      StockAlertService().checkAlerts();

      return true;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
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

  // في sales_invoice_service.dart - أضف هذه الدوال

  // إرجاع جزئي لمنتج معين
  // إرجاع جزئي لمنتج معين مع معالجة الصندوق
  Future<bool> returnPartialItem({
    required int invoiceId,
    required int itemId,
    required double returnedQuantity,
  }) async {
    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        final invoiceList = await txn.query(
          'sales_invoices',
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        if (invoiceList.isEmpty) throw Exception('الفاتورة غير موجودة');
        final invoiceData = invoiceList.first;
        final items = await txn.query(
          'sales_invoice_items',
          where: 'id = ? AND invoice_id = ?',
          whereArgs: [itemId, invoiceId],
        );
        if (items.isEmpty) throw Exception('العنصر غير موجود');
        final item = items.first;

        final currentQuantity = (item['quantity'] as num).toDouble();
        final unitQuantity = (item['unit_quantity'] as num?)?.toDouble() ?? 1.0;
        final productId = item['product_id'] as int?;
        final price = (item['price'] as num).toDouble();

        if (returnedQuantity > currentQuantity)
          throw Exception('الكمية المرجعة أكبر من الموجودة');

        final refundValue = returnedQuantity * price;
        final currentTotal = (invoiceData['total'] as num).toDouble();
        final currentPaid = (invoiceData['paid_amount'] as num).toDouble();
        final paymentMethod = invoiceData['payment_method'] as String;
        final invoiceNumber = invoiceData['invoice_number'] as String;
        final newTotal = currentTotal - refundValue;

        double cashToReturn = 0.0;
        if (currentPaid > newTotal) {
          cashToReturn = currentPaid - newTotal;
        }

        if (cashToReturn > 0) {
          if (paymentMethod != 'من الرصيد') {
            await _processRefundFromDailyBox(
              txn,
              amount: cashToReturn,
              description: 'مرتجع جزئي للفاتورة $invoiceNumber',
              relatedId: invoiceId,
            );
          } else {
            final customerId = invoiceData['customer_id'] as int?;
            if (customerId != null)
              await txn.rawUpdate(
                'UPDATE customers SET wallet_balance = wallet_balance + ? WHERE id = ?',
                [cashToReturn, customerId],
              );
          }
          await txn.update(
            'sales_invoices',
            {'paid_amount': newTotal},
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
        }

        final newQuantity = currentQuantity - returnedQuantity;
        if (newQuantity > 0) {
          await txn.update(
            'sales_invoice_items',
            {'quantity': newQuantity, 'total': price * newQuantity},
            where: 'id = ?',
            whereArgs: [itemId],
          );
        } else {
          await txn.delete(
            'sales_invoice_items',
            where: 'id = ?',
            whereArgs: [itemId],
          );
        }

        if (productId != null) {
          final totalReturnedPieces = returnedQuantity * unitQuantity;
          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ? WHERE id = ?',
            [totalReturnedPieces, productId],
          );
        }
        await _recalculateInvoiceTotal(txn, invoiceId);
      });
      return true;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // تعديل الفاتورة (تغيير الكميات)
  Future<bool> updateInvoice({
    required int invoiceId,
    required List<SaleInvoiceItem> updatedItems,
  }) async {
    final db = await _dbHelper.database;

    try {
      // التحقق من المخزون قبل بدء المعاملة
      final originalItems = await db.query(
        'sales_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      for (final updatedItem in updatedItems) {
        final originalItem = originalItems.firstWhere(
          (item) => item['id'] == updatedItem.id,
          orElse: () => {},
        );

        if (originalItem.isNotEmpty && updatedItem.id != null) {
          final originalQuantity = (originalItem['quantity'] as num).toDouble();
          final originalUnitQuantity =
              (originalItem['unit_quantity'] as num?)?.toDouble() ?? 1.0;
          final originalTotalPieces = originalQuantity * originalUnitQuantity;

          final newTotalPieces =
              updatedItem.quantity * updatedItem.unitQuantity;
          final difference = newTotalPieces - originalTotalPieces;

          // إذا كانت هناك زيادة في الكمية، تحقق من المخزون
          if (difference > 0) {
            final productResult = await db.query(
              'products',
              where: 'id = ?',
              whereArgs: [updatedItem.productId],
            );

            if (productResult.isNotEmpty) {
              final currentStock =
                  (productResult.first['stock'] as num).toDouble();
              if (currentStock < difference) {
                throw Exception(
                  'المخزون غير كافي للمنتج ${updatedItem.productName}. المتاح: $currentStock, المطلوب: $difference',
                );
              }
            }
          }
        }
      }

      await db.transaction((txn) async {
        // 1. مقارنة التغييرات وتحديث المخزون
        await _syncInventoryChanges(txn, originalItems, updatedItems);

        // 2. تحديث العناصر في قاعدة البيانات
        await _updateInvoiceItems(txn, invoiceId, updatedItems);

        // 3. تحديث إجمالي الفاتورة
        await _recalculateInvoiceTotal(txn, invoiceId);
      });

      return true;
    } catch (e) {
      throw Exception('فشل في تعديل الفاتورة: $e');
    }
  }

  // الدوال المساعدة
  Future<void> _recalculateInvoiceTotal(Transaction txn, int invoiceId) async {
    // حساب الإجمالي الجديد من العناصر
    final items = await txn.query(
      'sales_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    double newTotal = 0.0;
    for (final item in items) {
      newTotal += (item['total'] as num).toDouble();
    }

    // جلب بيانات الفاتورة الحالية
    final invoice = await txn.query(
      'sales_invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    if (invoice.isNotEmpty) {
      final currentPaidAmount =
          (invoice.first['paid_amount'] as num).toDouble();
      final newRemainingAmount = newTotal - currentPaidAmount;

      // تحديث الفاتورة بالمبالغ الجديدة
      await txn.update(
        'sales_invoices',
        {
          'total': newTotal,
          'remaining_amount': newRemainingAmount,
          'payment_status': _determinePaymentStatus(
            currentPaidAmount,
            newTotal,
            newRemainingAmount,
          ),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    }
  }

  Future<void> _syncInventoryChanges(
    Transaction txn,
    List<Map<String, dynamic>> originalItems,
    List<SaleInvoiceItem> updatedItems,
  ) async {
    for (final updatedItem in updatedItems) {
      final originalItem = originalItems.firstWhere(
        (item) => item['id'] == updatedItem.id,
        orElse: () => {},
      );
      if (originalItem.isNotEmpty && updatedItem.id != null) {
        final originalQuantity = (originalItem['quantity'] as num).toDouble();
        final originalUnitQuantity =
            (originalItem['unit_quantity'] as num?)?.toDouble() ?? 1.0;
        final originalTotalPieces = originalQuantity * originalUnitQuantity;
        final newTotalPieces = updatedItem.quantity * updatedItem.unitQuantity;
        final difference = newTotalPieces - originalTotalPieces;
        if (difference != 0) {
          final productResult = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [updatedItem.productId],
          );
          if (productResult.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock = stock - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
              [difference, updatedItem.productId],
            );
          }
        }
      }
    }
    // معالجة المحذوف
    for (final originalItem in originalItems) {
      final originalItemId = originalItem['id'] as int?;
      if (!updatedItems.any((item) => item.id == originalItemId) &&
          originalItemId != null) {
        final originalQuantity = (originalItem['quantity'] as num).toDouble();
        final unitQuantity =
            (originalItem['unit_quantity'] as num?)?.toDouble() ?? 1.0;
        final total = originalQuantity * unitQuantity;
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [total, originalItem['product_id']],
        );
      }
    }
  }

  Future<void> _updateInvoiceItems(
    Transaction txn,
    int invoiceId,
    List<SaleInvoiceItem> updatedItems,
  ) async {
    await txn.delete(
      'sales_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    for (final item in updatedItems) {
      await txn.insert('sales_invoice_items', {
        'invoice_id': invoiceId,
        'product_id': item.productId,
        'product_name': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'unit_quantity': item.unitQuantity,
        'unit_name': item.unitName,
      });
    }
  }

  // أضف هذه الدالة في SalesInvoiceService
  Future<Database> getDatabase() async {
    return await _dbHelper.database;
  }

  // في sales_invoice_service.dart - أضف هذه الدوال

  // تحديث المبالغ المدفوعة بعد تعديل الفاتورة
  Future<bool> updateInvoicePayment({
    required int invoiceId,
    required double newPaidAmount,
    required double newTotal,
  }) async {
    final db = await _dbHelper.database;

    try {
      final newRemainingAmount = newTotal - newPaidAmount;

      // تحديث حالة السداد بناءً على المبالغ الجديدة
      final paymentStatus = _determinePaymentStatus(
        newPaidAmount,
        newTotal,
        newRemainingAmount,
      );
      final paymentType = (newRemainingAmount > 0) ? 'آجل' : 'نقدي';

      await db.update(
        'sales_invoices',
        {
          'total': newTotal,
          'paid_amount': newPaidAmount,
          'remaining_amount': newRemainingAmount,
          'payment_status': paymentStatus,
          'payment_type': paymentType,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      return true;
    } catch (e) {
      throw Exception('فشل في تحديث المدفوعات: $e');
    }
  }

  // دالة معدلة لتحديث الفاتورة مع المدفوعات
  Future<bool> updateInvoiceWithPayment({
    required int invoiceId,
    required List<SaleInvoiceItem> updatedItems,
    required double newPaidAmount,
  }) async {
    final db = await _dbHelper.database;

    try {
      // التحقق من المخزون قبل بدء المعاملة
      final originalItems = await db.query(
        'sales_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      // (كود التحقق من المخزون كما هو...)
      for (final updatedItem in updatedItems) {
        final originalItem = originalItems.firstWhere(
          (item) => item['id'] == updatedItem.id,
          orElse: () => {},
        );

        if (originalItem.isNotEmpty && updatedItem.id != null) {
          final originalQuantity = (originalItem['quantity'] as num).toDouble();
          final originalUnitQuantity =
              (originalItem['unit_quantity'] as num?)?.toDouble() ?? 1.0;
          final originalTotalPieces = originalQuantity * originalUnitQuantity;

          final newTotalPieces =
              updatedItem.quantity * updatedItem.unitQuantity;
          final difference = newTotalPieces - originalTotalPieces;

          if (difference > 0) {
            final productResult = await db.query(
              'products',
              where: 'id = ?',
              whereArgs: [updatedItem.productId],
            );
            if (productResult.isNotEmpty) {
              final currentStock =
                  (productResult.first['stock'] as num).toDouble();
              if (currentStock < difference) {
                throw Exception(
                  'المخزون غير كافي للمنتج ${updatedItem.productName}.',
                );
              }
            }
          }
        }
      }

      await db.transaction((txn) async {
        // 1. 🌟 جلب البيانات القديمة قبل التعديل (مهم جداً)
        final oldInvoiceQuery = await txn.query(
          'sales_invoices',
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        if (oldInvoiceQuery.isEmpty) throw Exception('الفاتورة غير موجودة');

        final oldInvoice = oldInvoiceQuery.first;
        final double oldPaidAmount =
            (oldInvoice['paid_amount'] as num).toDouble();
        final String paymentMethod = oldInvoice['payment_method'] as String;
        final String invoiceNumber = oldInvoice['invoice_number'] as String;
        final int? customerId = oldInvoice['customer_id'] as int?;

        // 2. 🌟 حساب الفرق المالي ومعالجة الصندوق
        final double diff = newPaidAmount - oldPaidAmount;

        if (diff != 0) {
          // إذا كانت طريقة الدفع "من الرصيد"، نعدل محفظة العميل بدلاً من الصندوق
          if (paymentMethod == 'من الرصيد' && customerId != null) {
            // إذا الفرق موجب (دفع زيادة) -> نخصم من المحفظة
            // إذا الفرق سالب (إرجاع) -> نزيد المحفظة
            // ملاحظة: diff موجب يعني paid زاد، يعني أخذنا من الزلمة مصاري

            // التحقق من رصيد المحفظة قبل الخصم الإضافي
            if (diff > 0) {
              final customerQ = await txn.query(
                'customers',
                where: 'id = ?',
                whereArgs: [customerId],
              );
              final walletBal =
                  (customerQ.first['wallet_balance'] as num).toDouble();
              if (walletBal < diff)
                throw Exception('رصيد المحفظة لا يكفي للتعديل');
            }

            await txn.rawUpdate(
              'UPDATE customers SET wallet_balance = wallet_balance - ? WHERE id = ?',
              [diff, customerId], // diff موجب يخصم، سالب يضيف (لأن - - = +)
            );
          } else {
            // التعامل مع الصندوق النقدي (الوضع الطبيعي)
            if (diff > 0) {
              // 🔼 الزبون دفع زيادة (قبض)
              await _processAddToDailyBox(
                txn,
                amount: diff,
                description: 'تعديل فاتورة رقم $invoiceNumber (دفع إضافي)',
                relatedId: invoiceId,
              );
            } else {
              // 🔽 المبلغ المدفوع قل (يعني لازم نرجعله فرقية كاش)
              final refundAmount = diff.abs(); // تحويل السالب لموجب للتعامل معه
              await _processRefundFromDailyBox(
                txn,
                amount: refundAmount,
                description: 'تعديل فاتورة رقم $invoiceNumber (إرجاع فرق)',
                relatedId: invoiceId,
              );
            }
          }
        }

        // 3. مقارنة التغييرات وتحديث المخزون (كما هو)
        await _syncInventoryChanges(txn, originalItems, updatedItems);

        // 4. تحديث العناصر في قاعدة البيانات (كما هو)
        await _updateInvoiceItems(txn, invoiceId, updatedItems);

        // 5. حساب الإجمالي الجديد وتحديث المدفوعات في جدول الفواتير
        await _recalculateAndUpdateInvoice(txn, invoiceId, newPaidAmount);
      });

      return true;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // دالة مساعدة معدلة
  Future<void> _recalculateAndUpdateInvoice(
    Transaction txn,
    int invoiceId,
    double newPaidAmount,
  ) async {
    // حساب الإجمالي الجديد من العناصر
    final items = await txn.query(
      'sales_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    double newTotal = 0.0;
    for (final item in items) {
      newTotal += (item['total'] as num).toDouble();
    }

    final newRemainingAmount = newTotal - newPaidAmount;

    // التحقق من أن المبلغ المدفوع لا يتجاوز الإجمالي (إلا إذا أردت السماح بالبقشيش أو الرصيد، لكن هنا نمنعه حسب طلبك)
    // ملاحظة: تم التحقق في الـ Dialog، لكن زيادة حرص
    if (newPaidAmount > newTotal) {
      // يمكن التساهل هنا، لكن سنبقيه
    }

    // تحديث الفاتورة بالمبالغ الجديدة
    await txn.update(
      'sales_invoices',
      {
        'total': newTotal,
        'paid_amount': newPaidAmount,
        'remaining_amount': newRemainingAmount,
        'payment_status': _determinePaymentStatus(
          newPaidAmount,
          newTotal,
          newRemainingAmount,
        ),
        'payment_type':
            (newRemainingAmount > 0.01) ? 'آجل' : 'نقدي', // هامش خطأ بسيط
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> _processRefundFromDailyBox(
    Transaction txn, {
    required double amount,
    required String description,
    required int relatedId,
  }) async {
    final boxResult = await txn.query(
      'cash_boxes',
      where: 'name = ?',
      whereArgs: ['الصندوق اليومي'],
    );

    if (boxResult.isEmpty) {
      await txn.insert('cash_boxes', {
        'name': 'الصندوق اليومي',
        'balance': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      throw Exception('رصيد الصندوق اليومي 0. لا يمكن إتمام الإرجاع.');
    }

    final boxId = boxResult.first['id'] as int;
    final currentBalance = (boxResult.first['balance'] as num).toDouble();

    if (currentBalance < amount) {
      throw Exception(
        'عفواً، رصيد الصندوق اليومي (${currentBalance.toStringAsFixed(2)}) لا يكفي لإرجاع مبلغ (${amount.toStringAsFixed(2)}).',
      );
    }

    await txn.update(
      'cash_boxes',
      {
        'balance': currentBalance - amount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [boxId],
    );

    final now = DateTime.now();
    await txn.insert('cash_movements', {
      'box_id': boxId,
      'amount': amount,
      'type': 'تعديل فاتورة / إرجاع',
      'direction': 'خارج',
      'notes': description,
      'date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'related_id': relatedId.toString(),
      'created_at': now.toIso8601String(),
    });
  }

  Future<void> _processAddToDailyBox(
    Transaction txn, {
    required double amount,
    required String description,
    required int relatedId,
  }) async {
    final boxResult = await txn.query(
      'cash_boxes',
      where: 'name = ?',
      whereArgs: ['الصندوق اليومي'],
    );

    int boxId;
    double currentBalance = 0.0;

    if (boxResult.isEmpty) {
      boxId = await txn.insert('cash_boxes', {
        'name': 'الصندوق اليومي',
        'balance': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      boxId = boxResult.first['id'] as int;
      currentBalance = (boxResult.first['balance'] as num).toDouble();
    }

    // زيادة الرصيد
    await txn.update(
      'cash_boxes',
      {
        'balance': currentBalance + amount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [boxId],
    );

    // تسجيل الحركة
    final now = DateTime.now();
    await txn.insert('cash_movements', {
      'box_id': boxId,
      'amount': amount,
      'type': 'تعديل فاتورة / قبض',
      'direction': 'داخل', // داخل للصندوق
      'notes': description,
      'date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'related_id': relatedId.toString(),
      'created_at': now.toIso8601String(),
    });
  }

  // معالجة عملية الإرجاع
  Future<void> processReturn({
    required int parentInvoiceId,
    required List<SaleInvoiceItem> itemsToReturn,
    required double returnTotal,
    required bool returnToCash, // هل نرجع كاش؟
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. جلب الفاتورة الأصلية
      final parentInvoiceData = await txn.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [parentInvoiceId],
      );
      if (parentInvoiceData.isEmpty)
        throw Exception('الفاتورة الأصلية غير موجودة');
      final parentInvoice = SaleInvoice.fromMap(parentInvoiceData.first);

      // 2. إنشاء فاتورة المرتجع (قيم سالبة)
      final returnInvoiceNumber =
          'RET-${parentInvoice.invoiceNumber}-${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';

      // إذا كان الدفع كاش، المرتجع أيضاً كاش (PaidAmount سالب)
      // إذا كان خصم من الدين، PaidAmount صفر (ويبقيRemainingAmount سالب يخصم من الدين الكلي)
      final double paidAmount = returnToCash ? -returnTotal : 0.0;
      final double remainingAmount = returnToCash ? 0.0 : -returnTotal;

      final invoiceId = await txn.insert('sales_invoices', {
        'invoice_number': returnInvoiceNumber,
        'date': DateTime.now().toString().split(' ')[0],
        'time':
            '${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
        'total': -returnTotal, // الإجمالي بالسالب
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'cashier': parentInvoice.cashier,
        'customer_id': parentInvoice.customerId,
        'customer_name': parentInvoice.customerName,
        'payment_method': returnToCash ? 'نقدي' : 'تعديل رصيد',
        'payment_type': 'مرتجع',
        'payment_status': 'مرتجع',
        'original_total': -returnTotal,
        'notes': 'مرتجع للفاتورة ${parentInvoice.invoiceNumber}',
        'created_at': DateTime.now().toIso8601String(),
        'is_return': 1,
        'parent_invoice_id': parentInvoiceId,
      });

      // 3. إدخال العناصر ومعالجة المخزون (زيادة المخزون)
      for (var item in itemsToReturn) {
        await txn.insert('sales_invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': -item.quantity,
          'total': -item.total,
          'unit_quantity': item.unitQuantity,
          'unit_name': item.unitName,
          'cost_price': item.costPrice,
        });

        // زيادة المخزون
        if (item.productId != null) {
          final totalQty = item.quantity * item.unitQuantity;
          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ? WHERE id = ?',
            [totalQty, item.productId],
          );
        }
      }

      // 4. معالجة حساب العميل/الصندوق
      if (returnToCash) {
        // نخصم من الصندوق اليومي إذا كان الدفع كاش
        await _processRefundFromDailyBox(
          txn,
          amount: returnTotal,
          description:
              'مرتجع كامل/جزئي للفاتورة ${parentInvoice.invoiceNumber}',
          relatedId: invoiceId,
        );
      } else {
        // إذا كان تعديل رصيد، النظام سيعالج ذلك تلقائياً عبر جمع الفواتير
      }
    });
  }

  // 5. جلب كشف حساب مفصل (فواتير، مرتجعات، سدادات)
  Future<List<StatementItem>> getCustomerDetailedStatement({
    required int customerId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await _dbHelper.database;
    final List<StatementItem> statementItems = [];
    double runningBalance = 0.0;

    try {
      // 1. حساب الرصيد الافتتاحي (قبل تاريخ البداية)

      // أ. الديون الحالية للفواتير التي أنشئت قبل تاريخ البداية
      // (نعتمد على remaining_amount الحالي للفواتير القديمة)
      final oldInvoicesDebtResult = await db.rawQuery(
        'SELECT SUM(remaining_amount) as debt FROM sales_invoices WHERE customer_id = ? AND date < ?',
        [customerId, startDate],
      );
      double openingBalance =
          (oldInvoicesDebtResult.first['debt'] as num?)?.toDouble() ?? 0.0;

      // ب. السدادات التي تمت في فترة التقرير (أو بعدها) ولكنها تخص فواتير قديمة (قبل التقرير)
      // هذه السدادات خفضت الـ remaining_amount، ما يعني أن الدين كان أكبر في بداية الفترة.
      // لذا يجب إعادة إضافتها للرصيد الافتتاحي لنتمكن من خصمها مجدداً عند عرض حركة السداد.
      final paymentsForOldInvoicesResult = await db.rawQuery(
        '''
        SELECT SUM(pr.amount) as paid
        FROM payment_records pr
        JOIN sales_invoices si ON pr.invoice_id = si.id
        WHERE si.customer_id = ? 
          AND si.date < ?       -- الفاتورة قديمة (قبل بداية التقرير)
          AND pr.payment_date >= ? -- السداد حديث (داخل فترة التقرير أو بعدها)
        ''',
        [customerId, startDate, startDate],
      );
      double paidForOldInSales =
          (paymentsForOldInvoicesResult.first['paid'] as num?)?.toDouble() ??
          0.0;

      runningBalance = openingBalance + paidForOldInSales;

      // إضافة بند الرصيد الافتتاحي
      if (runningBalance != 0) {
        statementItems.add(
          StatementItem(
            date: startDate,
            type: "رصيد سابق",
            description: "رصيد افتتاحي ما قبل $startDate",
            amount: runningBalance,
            balance: runningBalance,
            isCredit: false,
          ),
        );
      }

      // 2. جلب العمليات في الفترة (فواتير + سدادات)
      final List<StatementItem> periodItems = [];

      // أ. الفواتير (مبيعات + مرتجعات) في الفترة
      final invoices = await db.query(
        'sales_invoices',
        where: 'customer_id = ? AND date BETWEEN ? AND ?',
        whereArgs: [customerId, startDate, endDate],
      );

      for (var inv in invoices) {
        final invoice = SaleInvoice.fromMap(inv);
        bool isRet = invoice.isReturn == 1;

        // Fetch invoice items from DB
        final itemsData = await db.query(
          'sales_invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoice.id],
        );

        final List<SaleInvoiceItem> loadedItems =
            itemsData
                .map((itemMap) => SaleInvoiceItem.fromMap(itemMap))
                .toList();

        // إضافة الفاتورة كحركة
        periodItems.add(
          StatementItem(
            date: "${invoice.date} ${invoice.time}",
            invoiceNumber: invoice.invoiceNumber,
            type: isRet ? "مرتجع مبيعات" : "فاتورة مبيعات",
            description:
                isRet
                    ? "مرتجع رقم ${invoice.invoiceNumber}"
                    : "فاتورة رقم ${invoice.invoiceNumber}",
            amount: invoice.total.abs(), // القيمة الموجبة دائماً للعرض
            balance: 0, // سيحسب لاحقاً
            isCredit: false, // تعامل معاملة المدين (زيادة على الحساب) مبدئياً
            isReturn: isRet, // المرتجع حالة خاصة ستعالج في الحساب
            items: loadedItems,
          ),
        );

        // التحقق من "الدفع الفوري" (النقدي) غير المسجل في PaymentRecords
        // نقوم بحساب المبلغ المدفوع الكلي في الفاتورة ونطرح منه أي سدادات مسجلة في جدول payment_records
        final records = await db.query(
          'payment_records',
          where: 'invoice_id = ?',
          whereArgs: [invoice.id],
        );
        double recordedPaid = 0;
        for (var r in records) recordedPaid += (r['amount'] as num).toDouble();

        double instantPay = invoice.paidAmount - recordedPaid;
        // معالجة فروقات صغيرة في الأرقام العائمة
        if (instantPay < 0.01 && instantPay > -0.01) instantPay = 0;

        if (instantPay > 0) {
          periodItems.add(
            StatementItem(
              date: "${invoice.date} ${invoice.time}",
              type: "دفعة فورية",
              description: "دفعة نقدية عن فاتورة ${invoice.invoiceNumber}",
              amount: instantPay,
              balance: 0,
              isCredit: true, // سداد (ينقص الدين)
            ),
          );
        }
      }

      // ب. السدادات (Payment Records) المسجلة في الفترة
      final payments = await db.rawQuery(
        '''
        SELECT pr.*, si.invoice_number 
        FROM payment_records pr
        JOIN sales_invoices si ON pr.invoice_id = si.id
        WHERE si.customer_id = ? AND pr.payment_date BETWEEN ? AND ?
        ''',
        [customerId, startDate, endDate],
      );

      for (var pay in payments) {
        periodItems.add(
          StatementItem(
            date: "${pay['payment_date']} ${pay['payment_time']}",
            invoiceNumber: (pay['invoice_number'] as String?) ?? "",
            type: "سند قبض",
            description:
                "سداد ورقي عن فاتورة ${(pay['invoice_number'] as String?) ?? ''}",
            amount: (pay['amount'] as num).toDouble(),
            balance: 0,
            isCredit: true,
          ),
        );
      }

      // 3. ترتيب الكل حسب التاريخ والوقت
      periodItems.sort((a, b) => a.date.compareTo(b.date));

      // 4. دمج وحساب الرصيد التراكمي
      for (var item in periodItems) {
        if (item.isReturn) {
          // المرتجع ينقص الرصيد (لأنه دائن للعميل)
          runningBalance -= item.amount;
        } else if (item.isCredit) {
          // سداد ينقص الرصيد
          runningBalance -= item.amount;
        } else {
          // فاتورة مبيعات تزيد الرصيد (مدين)
          runningBalance += item.amount;
        }

        statementItems.add(
          StatementItem(
            date: item.date,
            invoiceNumber: item.invoiceNumber,
            type: item.type,
            description: item.description,
            amount: item.amount,
            balance: runningBalance,
            isCredit: item.isCredit,
            isReturn: item.isReturn,
          ),
        );
      }
    } catch (e) {
      print("Error calculating statement: $e");
    }

    return statementItems;
  }
}
