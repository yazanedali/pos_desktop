class SaleInvoiceItem {
  int? id;
  int invoiceId;
  int productId;
  String productName;
  double price;
  int quantity;
  double total;

  SaleInvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

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

  factory SaleInvoiceItem.fromMap(Map<String, dynamic> map) {
    return SaleInvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      price:
          map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
      quantity: map['quantity'],
      total:
          map['total'] is int ? (map['total'] as int).toDouble() : map['total'],
    );
  }

  // إنشاء عنصر فاتورة جديد
  factory SaleInvoiceItem.createNew({
    required int invoiceId,
    required int productId,
    required String productName,
    required double price,
    required int quantity,
  }) {
    return SaleInvoiceItem(
      invoiceId: invoiceId,
      productId: productId,
      productName: productName,
      price: price,
      quantity: quantity,
      total: price * quantity,
    );
  }

  @override
  String toString() {
    return 'SaleInvoiceItem(product: $productName, quantity: $quantity, total: $total)';
  }
}
