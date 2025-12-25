import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/purchase_invoice.dart';
import 'package:sqflite/sqflite.dart';

class PurchaseQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ProductQueries productQueries = ProductQueries();

  // ثابت حجم الصفحة
  static const int pageSize = 15;

  // ========== دالة مساعدة لتحديث سعر شراء المنتج ==========
  Future<void> _updateProductPurchasePrice({
    required Transaction txn,
    required String productName,
  }) async {
    try {
      // استخدم المتوسط المرجح بالكمية بدلاً من المتوسط البسيط
      final result = await txn.rawQuery(
        '''
      SELECT 
        SUM(quantity * purchase_price) / SUM(quantity) as weighted_avg_price,
        SUM(quantity) as total_quantity
      FROM purchase_invoice_items
      WHERE product_name = ?
      HAVING SUM(quantity) > 0
    ''',
        [productName],
      );

      if (result.isNotEmpty && result.first['weighted_avg_price'] != null) {
        final avgPrice = result.first['weighted_avg_price'];
        double priceValue = 0.0;

        if (avgPrice is double)
          priceValue = avgPrice;
        else if (avgPrice is int)
          priceValue = avgPrice.toDouble();
        else if (avgPrice is String)
          priceValue = double.tryParse(avgPrice) ?? 0.0;

        await txn.update(
          'products',
          {'purchase_price': priceValue},
          where: 'name = ?',
          whereArgs: [productName],
        );
      } else {
        await txn.update(
          'products',
          {'purchase_price': 0.0},
          where: 'name = ?',
          whereArgs: [productName],
        );
      }
    } catch (e) {
      print('❌ خطأ في تحديث سعر شراء المنتج "$productName": $e');
    }
  }

  // دالة مساعدة لتحديث سعر شراء جميع المنتجات في الفاتورة
  Future<void> _updateAllProductsPurchasePrices({
    required Transaction txn,
    required List<PurchaseInvoiceItem> items,
  }) async {
    // تحديث سعر شراء كل منتج في الفاتورة
    for (final item in items) {
      await _updateProductPurchasePrice(
        txn: txn,
        productName: item.productName,
      );
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

  // ========== دالة إضافة فاتورة شراء (محدثة) ==========
  Future<PurchaseInvoice> insertPurchaseInvoice(PurchaseInvoice invoice) async {
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
      }

      // تحديث أسعار شراء جميع المنتجات في الفاتورة
      await _updateAllProductsPurchasePrices(txn: txn, items: invoice.items);
    });

    print('✅ تم إضافة فاتورة شراء وتحديث أسعار المنتجات');
    return invoice;
  }

  // ========== دالة تعديل فاتورة شراء (محدثة) ==========
  Future<void> updatePurchaseInvoice(PurchaseInvoice invoice) async {
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
          quantity: -oldItem.quantity, // ناقص لأننا نرجع الكمية
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
      }

      // تحديث أسعار شراء جميع المنتجات (القديمة والجديدة)
      final allProducts = [...oldItems, ...invoice.items];
      final uniqueProductNames =
          allProducts.map((item) => item.productName).toSet();

      for (final productName in uniqueProductNames) {
        await _updateProductPurchasePrice(txn: txn, productName: productName);
      }
    });

    print('✅ تم تحديث فاتورة الشراء وتحديث أسعار المنتجات');
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
        );
      }

      // حذف الفاتورة والعناصر
      await txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });

    print('✅ تم حذف فاتورة الشراء وتحديث أسعار المنتجات');
  }

  // ========== باقي الدوال كما هي ==========
  Future<List<PurchaseInvoice>> getPurchaseInvoicesPaginated({
    required int page,
    String? searchTerm,
  }) async {
    final db = await dbHelper.database;
    final offset = (page - 1) * pageSize;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause = 'invoice_number LIKE ? OR supplier LIKE ?';
      whereArgs = ['%$searchTerm%', '%$searchTerm%'];
    }

    final query = '''
      SELECT * FROM purchase_invoices 
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY created_at DESC 
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

  Future<int> getPurchaseInvoicesCount({String? searchTerm}) async {
    final db = await dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause = 'invoice_number LIKE ? OR supplier LIKE ?';
      whereArgs = ['%$searchTerm%', '%$searchTerm%'];
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

      print('🔄 جاري تحديث أسعار ${productNames.length} منتج...');

      int updatedCount = 0;
      for (final productName in productNames) {
        await _updateProductPurchasePrice(txn: txn, productName: productName);
        updatedCount++;
      }

      print('✅ تم تحديث أسعار $updatedCount منتج');
    });
  }
}
