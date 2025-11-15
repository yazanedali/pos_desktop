// services/purchase_service.dart
import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/purchase_invoice.dart';
import 'package:sqflite/sqflite.dart';

class PurchaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // إنشاء فاتورة شراء جديدة
  Future<String> createPurchaseInvoice({
    required List<PurchaseInvoiceItem> items,
    required String supplier,
  }) async {
    final db = await _dbHelper.database;

    try {
      // توليد رقم فاتورة
      final invoiceNumber = _generateInvoiceNumber();
      final now = DateTime.now();

      // حساب الإجمالي
      final total = items.fold(0.0, (sum, item) => sum + item.total);

      return await db.transaction((txn) async {
        // 1. إدخال الفاتورة الرئيسية
        final invoiceId = await txn.insert('purchase_invoices', {
          'invoice_number': invoiceNumber,
          'supplier': supplier,
          'date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'total': total,
          'created_at': now.toIso8601String(),
        });

        // 2. إدخال عناصر الفاتورة وإضافة المخزون
        for (final item in items) {
          // إدخال عنصر الفاتورة
          await txn.insert('purchase_invoice_items', {
            'invoice_id': invoiceId,
            'product_name': item.productName,
            'barcode': item.barcode,
            'category': item.category,
            'quantity': item.quantity,
            'purchase_price': item.purchasePrice,
            'sale_price': item.salePrice,
            'total': item.total,
          });

          // إذا كان المنتج موجوداً (من خلال الباركود)، تحديث المخزون والسعر
          if (item.barcode.isNotEmpty) {
            // التحقق إذا كان المنتج موجوداً
            final existingProduct = await txn.query(
              'products',
              where: 'barcode = ?',
              whereArgs: [item.barcode],
            );

            if (existingProduct.isNotEmpty) {
              // المنتج موجود - تحديث المخزون والسعر
              await txn.rawUpdate(
                'UPDATE products SET stock = stock + ?, price = ? WHERE barcode = ?',
                [item.quantity, item.salePrice, item.barcode],
              );
            } else {
              // المنتج غير موجود - إضافة منتج جديد
              await txn.insert('products', {
                'name': item.productName,
                'price': item.salePrice,
                'stock': item.quantity,
                'barcode': item.barcode,
                'category_id': await _getCategoryId(txn, item.category),
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        return invoiceNumber;
      });
    } catch (e) {
      throw Exception('فشل في إنشاء فاتورة الشراء: $e');
    }
  }

  Future<int?> _getCategoryId(
    DatabaseExecutor txn,
    String? categoryName,
  ) async {
    if (categoryName == null || categoryName.isEmpty) return null;

    final categories = await txn.query(
      'categories',
      where: 'name = ?',
      whereArgs: [categoryName],
    );

    if (categories.isNotEmpty) {
      return categories.first['id'] as int;
    }

    // إذا لم توجد الفئة، إنشاء فئة جديدة
    final newCategoryId = await txn.insert('categories', {
      'name': categoryName,
      'color': '#6B7280', // لون افتراضي
      'created_at': DateTime.now().toIso8601String(),
    });

    return newCategoryId;
  }

  // الحصول على جميع فواتير الشراء
  Future<List<PurchaseInvoice>> getAllPurchaseInvoices() async {
    final db = await _dbHelper.database;

    try {
      final invoices = await db.query(
        'purchase_invoices',
        orderBy: 'created_at DESC',
      );

      final List<PurchaseInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = PurchaseInvoice.fromMap(invoiceMap);
        final items = await _getInvoiceItems(invoice.id!);

        result.add(
          PurchaseInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            supplier: invoice.supplier,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في تحميل فواتير الشراء: $e');
    }
  }

  // الحصول على عناصر فاتورة محددة
  Future<List<PurchaseInvoiceItem>> _getInvoiceItems(int invoiceId) async {
    final db = await _dbHelper.database;

    try {
      final items = await db.query(
        'purchase_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      return items
          .map((itemMap) => PurchaseInvoiceItem.fromMap(itemMap))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // توليد رقم فاتورة
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    return 'PUR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
