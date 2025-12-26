import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/purchase_invoice.dart';
import 'package:sqflite/sqflite.dart';

class PurchaseQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ProductQueries productQueries = ProductQueries();

  // ثابت حجم الصفحة
  static const int pageSize = 15;

  // ========== دالة مساعدة لتحديث سعر شراء المنتج (مع الخيار) ==========
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
        print(
          '✅ تم تحديث سعر شراء "$productName" إلى $newPurchasePrice (السعر الجديد)',
        );
      } else {
        // الطريقة الافتراضية: المتوسط المرجح
        final result = await txn.rawQuery(
          '''
        SELECT 
          SUM(quantity * purchase_price) as total_cost,
          SUM(quantity) as total_quantity
        FROM purchase_invoice_items
        WHERE product_name = ?
      ''',
          [productName],
        );

        if (result.isNotEmpty) {
          final totalCost = result.first['total_cost'] as double? ?? 0.0;
          final totalQuantity =
              result.first['total_quantity'] as double? ?? 0.0;

          // حساب المتوسط المرجح
          final weightedAvg =
              (totalCost + (newPurchasePrice * newQuantity)) /
              (totalQuantity + newQuantity);

          await txn.update(
            'products',
            {'purchase_price': weightedAvg},
            where: 'name = ?',
            whereArgs: [productName],
          );

          print(
            '✅ تم تحديث سعر شراء "$productName" إلى $weightedAvg (المتوسط المرجح)',
          );
        } else {
          // إذا لم يكن هناك مشتريات سابقة
          await txn.update(
            'products',
            {'purchase_price': newPurchasePrice},
            where: 'name = ?',
            whereArgs: [productName],
          );
          print(
            '✅ تم تعيين سعر شراء "$productName" إلى $newPurchasePrice (أول شراء)',
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديث سعر شراء المنتج "$productName": $e');
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
    bool updateSalePrice = true, // ← معامل جديد لتحديث سعر البيع
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // إدخال الفاتورة الرئيسية
      final invoiceId = await txn.insert(
        'purchase_invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // إدخال العناصر وتحديث المخزون
      for (final item in invoice.items) {
        await txn.insert('purchase_invoice_items', {
          ...item.toMap(),
          'invoice_id': invoiceId,
        });

        // تحديث المخزون
        await _updateProductStock(
          txn: txn,
          barcode: item.barcode,
          productName: item.productName,
          quantity: item.quantity,
        );

        // تحديث سعر الشراء حسب الطريقة المختارة
        await _updateProductPurchasePrice(
          txn: txn,
          productName: item.productName,
          newPurchasePrice: item.purchasePrice,
          newQuantity: item.quantity.toInt(),
          updateMethod: purchasePriceUpdateMethod,
        );

        // تحديث سعر البيع (جديد) ← أضف هذا
        if (updateSalePrice && item.salePrice > 0) {
          await _updateProductSalePrice(
            txn: txn,
            productName: item.productName,
            newSalePrice: item.salePrice,
          );
        }
      }
    });

    return invoice;
  }

  // ========== دالة تعديل فاتورة شراء (محدثة مع الخيار) ==========
  Future<void> updatePurchaseInvoice(
    PurchaseInvoice invoice, {
    String purchasePriceUpdateMethod = 'جديد',
    bool updateSalePrice = true, // ← معامل جديد
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // جلب العناصر القديمة
      final oldItemsMaps = await txn.query(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );
      final oldItems =
          oldItemsMaps.map((map) => PurchaseInvoiceItem.fromMap(map)).toList();

      // تراجع عن تحديث المخزون للعناصر القديمة
      for (final oldItem in oldItems) {
        await _updateProductStock(
          txn: txn,
          barcode: oldItem.barcode,
          productName: oldItem.productName,
          quantity: -oldItem.quantity,
        );
      }

      // تحديث الفاتورة الرئيسية
      await txn.update(
        'purchase_invoices',
        invoice.toMap(),
        where: 'id = ?',
        whereArgs: [invoice.id],
      );

      // حذف العناصر القديمة
      await txn.delete(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // إضافة العناصر الجديدة وتحديث المخزون
      for (final newItem in invoice.items) {
        await txn.insert('purchase_invoice_items', {
          ...newItem.toMap(),
          'invoice_id': invoice.id,
        });

        // تحديث المخزون للعناصر الجديدة
        await _updateProductStock(
          txn: txn,
          barcode: newItem.barcode,
          productName: newItem.productName,
          quantity: newItem.quantity,
        );

        // تحديث سعر الشراء حسب الطريقة المختارة
        await _updateProductPurchasePrice(
          txn: txn,
          productName: newItem.productName,
          newPurchasePrice: newItem.purchasePrice,
          newQuantity: newItem.quantity.toInt(),
          updateMethod: purchasePriceUpdateMethod,
        );

        // تحديث سعر البيع (جديد) ← أضف هذا
        if (updateSalePrice && newItem.salePrice > 0) {
          await _updateProductSalePrice(
            txn: txn,
            productName: newItem.productName,
            newSalePrice: newItem.salePrice,
          );
        }
      }
    });
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

      // تحديث أسعار شراء المنتجات بعد الحذف
      for (final item in items) {
        await _updateProductPurchasePrice(
          txn: txn,
          productName: item.productName,
          newPurchasePrice: item.purchasePrice,
          newQuantity: item.quantity.toInt(),
          updateMethod: 'متوسط', // نستخدم المتوسط لإعادة الحساب
        );
      }

      // حذف الفاتورة والعناصر
      await txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });
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
}
