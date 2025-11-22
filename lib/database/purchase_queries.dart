import 'package:sqflite/sqflite.dart';
import '../models/purchase_invoice.dart';
import 'database_helper.dart';
import 'product_queries.dart';

class PurchaseQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ProductQueries productQueries = ProductQueries();

  // ثابت حجم الصفحة
  static const int pageSize = 15;

  // دالة جلب الفواتير بشكل مُرقّم
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

  // دالة جلب العدد الكلي للفواتير مع الفلترة
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

  // دالة مساعدة لتحديث مخزون المنتج - تستخدم txn داخل transaction
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

        // تحديث المخزون باستخدام الدالة المساعدة - نمرر txn
        await _updateProductStock(
          txn: txn,
          barcode: item.barcode,
          productName: item.productName,
          quantity: item.quantity,
        );
      }
    });

    return invoice;
  }

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
    });
  }

  // الدالة الأصلية يمكن أن تبقى للتوافق
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

      // حذف الفاتورة والعناصر
      await txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });
  }
}
