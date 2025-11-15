import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/cart_item.dart';

class SalesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // إنشاء فاتورة بيع جديدة
  Future<String> createSaleInvoice({
    required List<CartItem> cartItems,
    required String cashier,
    String? customerName,
    String paymentMethod = 'نقدي',
  }) async {
    final db = await _dbHelper.database;

    try {
      // توليد رقم فاتورة
      final invoiceNumber = _generateInvoiceNumber();
      final now = DateTime.now();

      // حساب الإجمالي
      final total = cartItems.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      // بدء transaction
      return await db.transaction((txn) async {
        // 1. إدخال الفاتورة الرئيسية
        final invoiceId = await txn.insert('sales_invoices', {
          'invoice_number': invoiceNumber,
          'date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'time':
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'total': total,
          'cashier': cashier,
          'customer_name': customerName,
          'payment_method': paymentMethod,
          'created_at': now.toIso8601String(),
        });

        // 2. إدخال عناصر الفاتورة وتحديث المخزون
        for (final item in cartItems) {
          // إدخال عنصر الفاتورة
          await txn.insert('sales_invoice_items', {
            'invoice_id': invoiceId,
            'product_id': item.id,
            'product_name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'total': item.price * item.quantity,
          });

          // تحديث مخزون المنتج
          await txn.rawUpdate(
            'UPDATE products SET stock = stock - ? WHERE id = ?',
            [item.quantity, item.id],
          );
        }

        return invoiceNumber;
      });
    } catch (e) {
      throw Exception('فشل في إنشاء الفاتورة: $e');
    }
  }

  // توليد رقم فاتورة
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
