// models/sales_invoice.dart
class SaleInvoice {
  final int id;
  final String invoiceNumber;
  final String date;
  final String time;
  final double total;
  final String cashier;
  final String? customerName;
  final String paymentMethod;
  final String? createdAt;
  final List<SaleInvoiceItem> items;

  SaleInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.time,
    required this.total,
    required this.cashier,
    this.customerName,
    this.paymentMethod = 'نقدي',
    this.createdAt,
    required this.items,
  });

  // تحويل من Map إلى SaleInvoice
  factory SaleInvoice.fromMap(Map<String, dynamic> map) {
    return SaleInvoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      date: map['date'],
      time: map['time'],
      total:
          map['total'] is int ? (map['total'] as int).toDouble() : map['total'],
      cashier: map['cashier'],
      customerName: map['customer_name'],
      paymentMethod: map['payment_method'] ?? 'نقدي',
      createdAt: map['created_at'],
      items: [], // سيتم تعبئتها لاحقاً
    );
  }

  // تحويل من SaleInvoice إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'date': date,
      'time': time,
      'total': total,
      'cashier': cashier,
      'customer_name': customerName,
      'payment_method': paymentMethod,
      'created_at': createdAt,
    };
  }
}

class SaleInvoiceItem {
  final int id;
  final int invoiceId;
  final int productId;
  final String productName;
  final double price;
  final double quantity;
  final double total;

  SaleInvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  // تحويل من Map إلى SaleInvoiceItem
  factory SaleInvoiceItem.fromMap(Map<String, dynamic> map) {
    return SaleInvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }

  // تحويل من SaleInvoiceItem إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}
