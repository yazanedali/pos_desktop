// class SaleInvoice {
//   final int? id;
//   final String invoiceNumber;
//   final String date;
//   final String time;
//   final double total;
//   final double paidAmount;
//   final double remainingAmount;
//   final String cashier;
//   final int? customerId;
//   final String? customerName;
//   final String paymentMethod;
//   final String paymentType;
//   final String paymentStatus;
//   final double originalTotal;
//   final String? notes;
//   final String createdAt;
//   final int? itemsCount;

//   SaleInvoice({
//     this.id,
//     required this.invoiceNumber,
//     required this.date,
//     required this.time,
//     required this.total,
//     required this.paidAmount,
//     required this.remainingAmount,
//     required this.cashier,
//     this.customerId,
//     this.customerName,
//     required this.paymentMethod,
//     required this.paymentType,
//     required this.paymentStatus,
//     required this.originalTotal,
//     this.notes,
//     required this.createdAt,
//     this.itemsCount,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       if (id != null) 'id': id,
//       'invoice_number': invoiceNumber,
//       'date': date,
//       'time': time,
//       'total': total,
//       'paid_amount': paidAmount,
//       'remaining_amount': remainingAmount,
//       'cashier': cashier,
//       'customer_id': customerId,
//       'customer_name': customerName,
//       'payment_method': paymentMethod,
//       'payment_type': paymentType,
//       'payment_status': paymentStatus,
//       'original_total': originalTotal,
//       'notes': notes,
//       'created_at': createdAt,
//     };
//   }

//   factory SaleInvoice.fromMap(Map<String, dynamic> map) {
//     return SaleInvoice(
//       id: map['id'],
//       invoiceNumber: map['invoice_number'],
//       date: map['date'],
//       time: map['time'],
//       total: (map['total'] as num).toDouble(),
//       paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
//       remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0.0,
//       cashier: map['cashier'],
//       customerId: map['customer_id'],
//       customerName: map['customer_name'],
//       paymentMethod: map['payment_method'] ?? 'نقدي',
//       paymentType: map['payment_type'] ?? 'نقدي',
//       paymentStatus: map['payment_status'] ?? 'مدفوع',
//       originalTotal:
//           (map['original_total'] as num?)?.toDouble() ??
//           (map['total'] as num).toDouble(),
//       notes: map['notes'],
//       createdAt: map['created_at'],
//       itemsCount: map['items_count'],
//     );
//   }
// }

// class SaleInvoiceItem {
//   final int? id;
//   final int invoiceId;
//   final int productId;
//   final String productName;
//   final double price;
//   final int quantity;
//   final double total;

//   SaleInvoiceItem({
//     this.id,
//     required this.invoiceId,
//     required this.productId,
//     required this.productName,
//     required this.price,
//     required this.quantity,
//     required this.total,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'invoice_id': invoiceId,
//       'product_id': productId,
//       'product_name': productName,
//       'price': price,
//       'quantity': quantity,
//       'total': total,
//     };
//   }

//   factory SaleInvoiceItem.fromMap(Map<String, dynamic> map) {
//     return SaleInvoiceItem(
//       id: map['id'],
//       invoiceId: map['invoice_id'],
//       productId: map['product_id'],
//       productName: map['product_name'],
//       price:
//           map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
//       quantity: map['quantity'],
//       total:
//           map['total'] is int ? (map['total'] as int).toDouble() : map['total'],
//     );
//   }
// }
