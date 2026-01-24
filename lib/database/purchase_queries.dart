import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/purchase_invoice.dart';
import 'package:pos_desktop/services/stock_alert_service.dart';
import 'package:sqflite/sqflite.dart';

class PurchaseQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ProductQueries productQueries = ProductQueries();

  // ثابت حجم الصفحة
  static const int pageSize = 15;

  Future<void> _updateProductPurchasePrice({
    required Transaction txn,
    required String productName,
    required double newPurchasePrice,
    required int newQuantity,
    required String updateMethod, // 'متوسط' أو 'جديد'
  }) async {
    try {
      if (updateMethod == 'جديد') {
        // الطريقة الجديدة: استخدام السعر الجديد فقط
        await txn.update(
          'products',
          {'purchase_price': newPurchasePrice},
          where: 'name = ?',
          whereArgs: [productName],
        );
      } else {
        // الطريقة المُصَحَّحة: المتوسط المرجح بناءً على المخزون الحالي

        // 1. جلب البيانات الحالية للمنتج
        final productResult = await txn.rawQuery(
          '''
        SELECT stock, purchase_price 
        FROM products 
        WHERE name = ? 
        LIMIT 1
        ''',
          [productName],
        );

        if (productResult.isNotEmpty) {
          final currentStock = productResult.first['stock'] as double? ?? 0.0;
          final currentPurchasePrice =
              productResult.first['purchase_price'] as double? ?? 0.0;

          // 2. حساب المتوسط المرجح
          double weightedAvg;

          if (currentStock <= 0) {
            // إذا كان المخزون صفر أو أقل، نستخدم السعر الجديد فقط
            weightedAvg = newPurchasePrice;
          } else {
            // حساب المتوسط المرجح الصحيح:
            // (الكمية الحالية × السعر الحالي) + (الكمية الجديدة × السعر الجديد)
            // ثم القسمة على إجمالي الكمية
            final totalCurrentCost = currentStock * currentPurchasePrice;
            final totalNewCost = newQuantity * newPurchasePrice;
            final totalQuantity = currentStock + newQuantity;

            weightedAvg = (totalCurrentCost + totalNewCost) / totalQuantity;
          }

          // 3. تحديث سعر الشراء في جدول المنتجات
          await txn.update(
            'products',
            {'purchase_price': weightedAvg},
            where: 'name = ?',
            whereArgs: [productName],
          );
        } else {
          // إذا لم يتم العثور على المنتج، نستخدم السعر الجديد
          await txn.update(
            'products',
            {'purchase_price': newPurchasePrice},
            where: 'name = ?',
            whereArgs: [productName],
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديث سعر شراء المنتج "$productName": $e');
      // إعادة رمي الخطأ للحفاظ على المعاملة (transaction)
      rethrow;
    }
  }

  // دالة مساعدة لتحديث مخزون المنتج
  Future<void> _updateProductStock({
    required Transaction txn,
    required String? barcode,
    required String productName,
    required double quantity,
  }) async {
    // تحديث المخزون بناءً على الباركود إذا كان موجوداً
    if (barcode != null && barcode.isNotEmpty) {
      final updatedRows = await txn.rawUpdate(
        'UPDATE products SET stock = stock + ? WHERE barcode = ?',
        [quantity, barcode],
      );

      if (updatedRows > 0) {
        return;
      }
    }

    // إذا لم يتم العثور على المنتج بالباركود، نبحث بالاسم
    final updatedRows = await txn.rawUpdate(
      'UPDATE products SET stock = stock + ? WHERE name = ?',
      [quantity, productName],
    );

    if (updatedRows > 0) {
    } else {
      print('⚠️ تحذير: لم يتم العثور على المنتج "$productName" لتحديث المخزون');
    }
  }

  Future<PurchaseInvoice> insertPurchaseInvoice(
    PurchaseInvoice invoice, {
    String purchasePriceUpdateMethod = 'جديد',
    bool updateSalePrice = true,
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // إدخال الفاتورة الرئيسية
      final invoiceId = await txn.insert(
        'purchase_invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // أولاً: تحديث أسعار الشراء (قبل تحديث المخزون)
      for (final item in invoice.items) {
        await txn.insert('purchase_invoice_items', {
          ...item.toMap(),
          'invoice_id': invoiceId,
        });

        // تحديث سعر الشراء أولاً (باستخدام المخزون الحالي قبل الإضافة)
        await _updateProductPurchasePrice(
          txn: txn,
          productName: item.productName,
          newPurchasePrice: item.purchasePrice,
          newQuantity: item.quantity.toInt(),
          updateMethod: purchasePriceUpdateMethod,
        );

        // ثم تحديث المخزون
        await _updateProductStock(
          txn: txn,
          barcode: item.barcode,
          productName: item.productName,
          quantity: item.quantity,
        );

        // تحديث سعر البيع
        if (updateSalePrice && item.salePrice > 0) {
          await _updateProductSalePrice(
            txn: txn,
            productName: item.productName,
            newSalePrice: item.salePrice,
          );
        }
      }
    });

    // تحديث تنبيهات المخزون بعد إضافة الفاتورة
    StockAlertService().checkAlerts();

    return invoice;
  }

  // ========== دالة تعديل فاتورة شراء (محدثة - إصلاح مشكلة القفل Database Locked) ==========
  Future<void> updatePurchaseInvoice(
    PurchaseInvoice invoice, {
    String purchasePriceUpdateMethod = 'جديد',
    bool updateSalePrice = true,
    String? boxName,
  }) async {
    final db = await dbHelper.database;
    // ❌ لا نستخدم CashService هنا لأنه يفتح اتصالاً جديداً يسبب القفل
    // final CashService cashService = CashService();

    await db.transaction((txn) async {
      // 1. جلب المدفوع القديم
      final List<Map<String, dynamic>> oldInvoiceResult = await txn.query(
        'purchase_invoices',
        columns: ['paid_amount', 'total'],
        where: 'id = ?',
        whereArgs: [invoice.id],
      );

      double oldPaidAmount = 0.0;
      if (oldInvoiceResult.isNotEmpty) {
        oldPaidAmount = oldInvoiceResult.first['paid_amount'] as double? ?? 0.0;
      }

      // 2. تجهيز المتغيرات الجديدة
      double newNetTotal = invoice.total;
      double finalPaidAmount = invoice.paidAmount;
      double finalRemainingAmount = invoice.remainingAmount;
      String finalPaymentStatus = invoice.paymentStatus;

      // 3. فحص الفائض
      if (oldPaidAmount > newNetTotal) {
        double refundAmount = oldPaidAmount - newNetTotal;

        finalPaidAmount = newNetTotal;
        finalRemainingAmount = 0.0;
        finalPaymentStatus = 'مدفوع';

        if (boxName != null && refundAmount > 0) {
          // ✅ الحل: تنفيذ عمليات الصندوق يدوياً باستخدام txn الحالي لتجنب القفل

          // أ. البحث عن الصندوق
          final List<Map<String, dynamic>> boxResult = await txn.query(
            'cash_boxes',
            where: 'name = ?',
            whereArgs: [boxName],
            limit: 1,
          );

          if (boxResult.isNotEmpty) {
            final int boxId = boxResult.first['id'];
            final DateTime now = DateTime.now();
            final String date =
                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
            final String time =
                "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

            // ب. تسجيل الحركة
            await txn.insert('cash_movements', {
              'box_id': boxId,
              'amount': refundAmount,
              'type': 'استرداد مشتريات',
              'direction': 'داخل', // دخول فلوس للصندوق
              'notes': 'فائض تعديل فاتورة شراء #${invoice.invoiceNumber}',
              'date': date,
              'time': time,
              'related_id': invoice.invoiceNumber,
              'created_at': now.toIso8601String(),
            });

            // ج. تحديث رصيد الصندوق (زيادة الرصيد)
            await txn.rawUpdate(
              'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
              [refundAmount, boxId],
            );
          }
        }
      }

      PurchaseInvoice finalInvoice = invoice.copyWith(
        paidAmount: finalPaidAmount,
        remainingAmount: finalRemainingAmount,
        paymentStatus: finalPaymentStatus,
      );

      // --- باقي العمليات (المخزون والمنتجات) كما هي ---

      // أ. تراجع عن المخزون القديم
      final oldItemsMaps = await txn.query(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [finalInvoice.id],
      );
      final oldItems =
          oldItemsMaps.map((map) => PurchaseInvoiceItem.fromMap(map)).toList();
      for (final oldItem in oldItems) {
        await _updateProductStock(
          txn: txn,
          barcode: oldItem.barcode,
          productName: oldItem.productName,
          quantity: -oldItem.quantity,
        );
      }

      // ب. تحديث الفاتورة
      await txn.update(
        'purchase_invoices',
        finalInvoice.toMap(),
        where: 'id = ?',
        whereArgs: [finalInvoice.id],
      );

      // ج. حذف العناصر القديمة
      await txn.delete(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [finalInvoice.id],
      );

      // د. إضافة العناصر الجديدة
      for (final newItem in finalInvoice.items) {
        await txn.insert('purchase_invoice_items', {
          ...newItem.toMap(),
          'invoice_id': finalInvoice.id,
        });

        await _updateProductStock(
          txn: txn,
          barcode: newItem.barcode,
          productName: newItem.productName,
          quantity: newItem.quantity,
        );

        await _updateProductPurchasePrice(
          txn: txn,
          productName: newItem.productName,
          newPurchasePrice: newItem.purchasePrice,
          newQuantity: newItem.quantity.toInt(),
          updateMethod: purchasePriceUpdateMethod,
        );

        if (updateSalePrice && newItem.salePrice > 0) {
          await _updateProductSalePrice(
            txn: txn,
            productName: newItem.productName,
            newSalePrice: newItem.salePrice,
          );
        }
      }
    });

    // تحديث تنبيهات المخزون بعد تعديل الفاتورة
    StockAlertService().checkAlerts();
  }

  // في purchase_queries.dart
  Future<void> _updateProductSalePrice({
    required Transaction txn,
    required String productName,
    required double newSalePrice,
  }) async {
    try {
      await txn.update(
        'products',
        {'price': newSalePrice},
        where: 'name = ?',
        whereArgs: [productName],
      );
    } catch (e) {
      print('❌ خطأ في تحديث سعر بيع المنتج "$productName": $e');
    }
  }

  // ========== دالة حذف فاتورة شراء (محدثة) ==========
  // ========== دالة حذف فاتورة شراء (محدثة) ==========
  Future<void> deletePurchaseInvoice(int id) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // جلب العناصر أولاً لتراجع تحديث المخزون
      final itemsMaps = await txn.query(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      final items =
          itemsMaps.map((map) => PurchaseInvoiceItem.fromMap(map)).toList();

      // تراجع تحديث المخزون
      for (final item in items) {
        await _updateProductStock(
          txn: txn,
          barcode: item.barcode,
          productName: item.productName,
          quantity: -item.quantity, // ناقص لأننا نحذف الفاتورة
        );
      }

      // إعادة حساب أسعار الشراء بعد الحذف
      for (final item in items) {
        // نستخدم طريقة 'متوسط' لإعادة الحساب
        await _updateProductPurchasePrice(
          txn: txn,
          productName: item.productName,
          newPurchasePrice: 0.0, // لن يؤثر لأنه حساب معكوس
          newQuantity: -item.quantity.toInt(), // كمية سالبة لأننا نحذف
          updateMethod: 'متوسط',
        );
      }

      // حذف الفاتورة والعناصر
      await txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });

    // تحديث تنبيهات المخزون بعد حذف الفاتورة
    StockAlertService().checkAlerts();
  }

  // ========== دالة الحصول على فواتير الشراء مع فلترة (محدثة) ==========
  Future<List<PurchaseInvoice>> getPurchaseInvoicesPaginated({
    required int page,
    String? searchTerm,
    String? paymentStatus,
  }) async {
    final db = await dbHelper.database;
    final offset = (page - 1) * pageSize;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    final conditions = <String>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add('(invoice_number LIKE ? OR supplier LIKE ?)');
      whereArgs.add('%$searchTerm%');
      whereArgs.add('%$searchTerm%');
    }

    if (paymentStatus != null &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'الكل') {
      conditions.add('payment_status = ?');
      whereArgs.add(paymentStatus);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    final query = '''
      SELECT * FROM purchase_invoices 
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY date DESC, time DESC
      LIMIT ? OFFSET ?
    ''';

    whereArgs.addAll([pageSize, offset]);

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);

    if (maps.isEmpty) {
      return [];
    }

    // جلب المنتجات لكل فاتورة
    return Future.wait(
      maps.map((invoiceMap) async {
        final items = await getPurchaseInvoiceItems(invoiceMap['id']);
        return PurchaseInvoice.fromMap(invoiceMap).copyWith(items: items);
      }),
    );
  }

  // ========== دالة الحصول على عدد فواتير الشراء مع فلترة (محدثة) ==========
  Future<int> getPurchaseInvoicesCount({
    String? searchTerm,
    String? paymentStatus,
  }) async {
    final db = await dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    final conditions = <String>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add('(invoice_number LIKE ? OR supplier LIKE ?)');
      whereArgs.add('%$searchTerm%');
      whereArgs.add('%$searchTerm%');
    }

    if (paymentStatus != null &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'الكل') {
      conditions.add('payment_status = ?');
      whereArgs.add(paymentStatus);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    final query = '''
      SELECT COUNT(*) as count FROM purchase_invoices 
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
    ''';

    final result = await db.rawQuery(query, whereArgs);
    return result.first['count'] as int? ?? 0;
  }

  Future<List<PurchaseInvoice>> getPurchaseInvoices() async {
    return getPurchaseInvoicesPaginated(page: 1);
  }

  Future<List<PurchaseInvoiceItem>> getPurchaseInvoiceItems(
    int invoiceId,
  ) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    return List.generate(maps.length, (i) {
      return PurchaseInvoiceItem.fromMap(maps[i]);
    });
  }

  // ========== دالة إضافية: تحديث جميع أسعار الشراء مرة واحدة ==========
  Future<void> updateAllProductsPurchasePrices() async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // الحصول على جميع أسماء المنتجات الفريدة
      final productNamesResult = await txn.rawQuery('''
        SELECT DISTINCT product_name 
        FROM purchase_invoice_items
        UNION
        SELECT name as product_name 
        FROM products
      ''');

      final productNames =
          productNamesResult
              .map((row) => row['product_name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .map((name) => name!)
              .toList();

      for (final productName in productNames) {
        await _updateProductPurchasePrice(
          txn: txn,
          productName: productName,
          newPurchasePrice: 0.0,
          newQuantity: 0,
          updateMethod: 'متوسط',
        );
      }
    });
  }

  // ========== دالة الحصول على كشف حساب المورد ==========
  Future<List<PurchaseInvoice>> getSupplierStatement({
    required int supplierId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await dbHelper.database;

    try {
      final invoices = await db.rawQuery(
        '''
      SELECT * FROM purchase_invoices 
      WHERE supplier_id = ? 
        AND date BETWEEN ? AND ?
      ORDER BY date DESC, time DESC
    ''',
        [supplierId, startDate, endDate],
      );

      // جلب المنتجات لكل فاتورة
      return Future.wait(
        invoices.map((invoiceMap) async {
          final items = await getPurchaseInvoiceItems(invoiceMap['id'] as int);
          return PurchaseInvoice.fromMap(invoiceMap).copyWith(items: items);
        }),
      );
    } catch (e) {
      throw Exception('فشل في تحميل كشف حساب المورد: $e');
    }
  }
}
