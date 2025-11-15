import 'package:sqflite/sqflite.dart';
import '../models/purchase_invoice.dart';
import 'database_helper.dart';
import 'product_queries.dart';

class PurchaseQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ProductQueries productQueries = ProductQueries();

  Future<PurchaseInvoice> insertPurchaseInvoice(PurchaseInvoice invoice) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      final invoiceId = await txn.insert(
        'purchase_invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final item in invoice.items) {
        // إضافة المنتج إلى الفاتورة
        await txn.insert('purchase_invoice_items', {
          ...item.toMap(),
          'invoice_id': invoiceId,
        });
        // تحديث مخزون المنتج
        await txn.rawUpdate(
          '''
          UPDATE products 
          SET stock = stock + ? 
          WHERE barcode = ?
        ''',
          [item.quantity, item.barcode],
        );
      }
    });
    return invoice;
  }

  Future<void> updatePurchaseInvoice(PurchaseInvoice invoice) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. جلب المنتجات القديمة في الفاتورة لتعديل المخزون
      final oldItemsMaps = await txn.query(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );
      final oldItems =
          oldItemsMaps.map((map) => PurchaseInvoiceItem.fromMap(map)).toList();

      // 2. إلغاء تأثير الفاتورة القديمة على المخزون (طرح الكميات القديمة)
      for (final oldItem in oldItems) {
        await txn.rawUpdate(
          '''
          UPDATE products 
          SET stock = stock - ? 
          WHERE barcode = ?
        ''',
          [oldItem.quantity, oldItem.barcode],
        );
      }

      // 3. تحديث بيانات الفاتورة الأساسية
      await txn.update(
        'purchase_invoices',
        invoice.toMap(),
        where: 'id = ?',
        whereArgs: [invoice.id],
      );

      // 4. حذف جميع المنتجات القديمة المرتبطة بالفاتورة
      await txn.delete(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // 5. إضافة المنتجات الجديدة وتحديث المخزون بها
      for (final newItem in invoice.items) {
        await txn.insert('purchase_invoice_items', {
          ...newItem.toMap(),
          'invoice_id': invoice.id,
        });
        // تطبيق الكميات الجديدة على المخزون
        await txn.rawUpdate(
          '''
          UPDATE products 
          SET stock = stock + ? 
          WHERE barcode = ?
        ''',
          [newItem.quantity, newItem.barcode],
        );
      }
    });
  }

  Future<List<PurchaseInvoice>> getPurchaseInvoices() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_invoices',
      orderBy: 'created_at DESC', // عرض الأحدث أولاً
    );

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
    await db.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
  }
}
