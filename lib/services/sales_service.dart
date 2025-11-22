// import 'package:pos_desktop/database/database_helper.dart';
// import 'package:pos_desktop/models/cart_item.dart';

// class SalesService {
//   final DatabaseHelper _dbHelper = DatabaseHelper();

//   // إنشاء فاتورة بيع جديدة مع دعم حقول الدفع والعميل
//   Future<String> createSaleInvoice({
//     required List<CartItem> cartItems,
//     required String cashier,
//     required double total,
//     required double paidAmount,
//     required double remainingAmount,
//     required String paymentMethod,
//     int? customerId, // معرّف العميل، يمكن أن يكون فارغاً في البيع النقدي
//   }) async {
//     final db = await _dbHelper.database;

//     try {
//       // توليد رقم فاتورة فريد
//       final invoiceNumber = _generateInvoiceNumber();
//       final now = DateTime.now();
//       final date =
//           '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
//       final time =
//           '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

//       // بدء transaction لضمان تنفيذ كل العمليات معاً أو إلغائها معاً
//       return await db.transaction((txn) async {
//         // 1. إدخال الفاتورة الرئيسية بالبيانات الجديدة
//         final invoiceId = await txn.insert('sales_invoices', {
//           'invoice_number': invoiceNumber,
//           'date': date,
//           'time': time,
//           'total': total,
//           'paid_amount': paidAmount, // <-- حقل جديد
//           'remaining_amount': remainingAmount, // <-- حقل جديد
//           'cashier': cashier,
//           'payment_method': paymentMethod,
//           'customer_id': customerId, // <-- حقل جديد
//           'created_at': now.toIso8601String(),
//         });

//         for (final item in cartItems) {
//           String finalProductName;

//           if (item.unitName == 'حبة') {
//             // <-- تأكد من مطابقة هذا الاسم
//             finalProductName = item.name;
//           }
//           // إذا كانت أي وحدة أخرى، قم بدمج الاسمين.
//           else {
//             finalProductName = '${item.name} (${item.unitName})';
//           }
//           await txn.insert('sales_invoice_items', {
//             'invoice_id': invoiceId,
//             'product_id': item.id,
//             'product_name': finalProductName,
//             'price': item.price,
//             'quantity': item.quantity,
//             'total': item.price * item.quantity,
//           });

//           // حساب الكمية الإجمالية للخصم من المخزون
//           final double quantityToDecrement = item.unitQuantity * item.quantity;

//           // تحديث مخزون المنتج بالكمية الصحيحة
//           await txn.rawUpdate(
//             'UPDATE products SET stock = stock - ? WHERE id = ?',
//             [quantityToDecrement, item.id],
//           );
//         }

//         return "invoiceNumber"; // return invoiceNumber;
//       });
//     } catch (e) {
//       throw Exception('فشل في إنشاء الفاتورة: $e');
//     }
//   }

//   // توليد رقم فاتورة
//   String _generateInvoiceNumber() {
//     final now = DateTime.now();
//     return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
//   }
// }
