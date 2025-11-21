// import '../models/sale_invoice.dart';
// import 'database_helper.dart';
// import 'product_queries.dart';

// class SalesQueries {
//   final DatabaseHelper dbHelper = DatabaseHelper();
//   final ProductQueries productQueries = ProductQueries();

//   Future<List<SaleInvoice>> getAllInvoices() async {
//     final db = await dbHelper.database;
//     final results = await db.rawQuery('''
//       SELECT 
//         si.*,
//         (SELECT COUNT(*) FROM sales_invoice_items WHERE invoice_id = si.id) as items_count
//       FROM sales_invoices si
//       ORDER BY si.created_at DESC
//     ''');

//     return results.map((map) => SaleInvoice.fromMap(map)).toList();
//   }

//   Future<SaleInvoice?> getInvoiceById(int id) async {
//     final db = await dbHelper.database;
//     final results = await db.query(
//       'sales_invoices',
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//     return results.isNotEmpty ? SaleInvoice.fromMap(results.first) : null;
//   }

//   Future<List<SaleInvoiceItem>> getInvoiceItems(int invoiceId) async {
//     final db = await dbHelper.database;
//     final results = await db.query(
//       'sales_invoice_items',
//       where: 'invoice_id = ?',
//       whereArgs: [invoiceId],
//     );

//     return results.map((map) => SaleInvoiceItem.fromMap(map)).toList();
//   }

//   Future<SaleInvoice> createInvoice({
//     required String invoiceNumber,
//     required String date,
//     required String time,
//     required List<SaleInvoiceItem> items,
//     required double total,
//     required String cashier,
//     int? customerId,
//     String paymentMethod = 'نقدي',
//     double paidAmount = 0.0,
//     double remainingAmount = 0.0,
//   }) async {
//     final db = await dbHelper.database;

//     // تحديد نوع الدفع وحالة السداد بناءً على المبالغ
//     final String paymentType = (remainingAmount > 0) ? 'آجل' : 'نقدي';
//     final String paymentStatus = _determinePaymentStatus(
//       paidAmount,
//       total,
//       remainingAmount,
//     );

//     // بدء transaction
//     await db.transaction((txn) async {
//       // إدخال الفاتورة الرئيسية مع الحقول الجديدة
//       final invoiceId = await txn.insert('sales_invoices', {
//         'invoice_number': invoiceNumber,
//         'date': date,
//         'time': time,
//         'total': total,
//         'paid_amount': paidAmount,
//         'remaining_amount': remainingAmount,
//         'cashier': cashier,
//         'customer_id': customerId,
//         'payment_method': paymentMethod,
//         'payment_type': paymentType,
//         'payment_status': paymentStatus,
//         'original_total': total,
//       });

//       // إدخال عناصر الفاتورة
//       for (final item in items) {
//         await txn.insert('sales_invoice_items', {
//           'invoice_id': invoiceId,
//           'product_id': item.productId,
//           'product_name': item.productName,
//           'price': item.price,
//           'quantity': item.quantity,
//           'total': item.total,
//         });

//         // تحديث مخزون المنتج
//         final product = await productQueries.getProductById(item.productId);
//         if (product != null) {
//           final newStock = product.stock - item.quantity;
//           await txn.update(
//             'products',
//             {'stock': newStock},
//             where: 'id = ?',
//             whereArgs: [item.productId],
//           );
//         }
//       }
//     });

//     // الحصول على الفاتورة المضافة
//     final results = await db.query(
//       'sales_invoices',
//       where: 'invoice_number = ?',
//       whereArgs: [invoiceNumber],
//     );

//     return SaleInvoice.fromMap(results.first);
//   }

//   String _determinePaymentStatus(
//     double paidAmount,
//     double total,
//     double remainingAmount,
//   ) {
//     if (paidAmount == 0) return 'غير مدفوع';
//     if (remainingAmount > 0) return 'جزئي';
//     return 'مدفوع';
//   }

//   Future<List<SaleInvoice>> searchInvoices(String searchTerm) async {
//     final db = await dbHelper.database;
//     final results = await db.rawQuery(
//       '''
//       SELECT 
//         si.*,
//         (SELECT COUNT(*) FROM sales_invoice_items WHERE invoice_id = si.id) as items_count
//       FROM sales_invoices si
//       WHERE si.invoice_number LIKE ? OR si.cashier LIKE ? OR si.customer_name LIKE ?
//       ORDER BY si.created_at DESC
//     ''',
//       ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
//     );

//     return results.map((map) => SaleInvoice.fromMap(map)).toList();
//   }

//   Future<List<Map<String, dynamic>>> getSalesReport({
//     String? startDate,
//     String? endDate,
//   }) async {
//     final db = await dbHelper.database;

//     String query = '''
//       SELECT 
//         si.date,
//         COUNT(si.id) as invoices_count,
//         SUM(si.total) as total_sales
//       FROM sales_invoices si
//     ''';

//     List<dynamic> params = [];

//     if (startDate != null && endDate != null) {
//       query += ' WHERE si.date BETWEEN ? AND ?';
//       params.addAll([startDate, endDate]);
//     }

//     query += ' GROUP BY si.date ORDER BY si.date DESC';

//     return await db.rawQuery(query, params);
//   }
// }
