class PurchaseInvoice {
  final int? id;
  final String invoiceNumber;
  final String supplier;
  final String date;
  final String time;
  final List<PurchaseInvoiceItem> items;
  final double total;
  final String? createdAt;

  PurchaseInvoice({
    this.id,
    required this.invoiceNumber,
    required this.supplier,
    required this.date,
    required this.time,
    required this.items,
    required this.total,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'supplier': supplier,
      'date': date,
      'time': time,
      'total': total,
      'created_at': createdAt,
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      supplier: map['supplier'],
      date: map['date'],
      time: map['time'],
      items: [],
      total:
          map['total'] is int ? (map['total'] as int).toDouble() : map['total'],
      createdAt: map['created_at'],
    );
  }

  PurchaseInvoice copyWith({
    int? id,
    String? invoiceNumber,
    String? supplier,
    String? date,
    String? time,
    List<PurchaseInvoiceItem>? items,
    double? total,
    String? createdAt,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplier: supplier ?? this.supplier,
      date: date ?? this.date,
      time: time ?? this.time,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PurchaseInvoiceItem {
  final int? id;
  final String productName;
  final String barcode;
  final int quantity;
  final double purchasePrice;
  final double salePrice;
  final String category;
  final double total;

  PurchaseInvoiceItem({
    this.id,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.purchasePrice,
    required this.salePrice,
    required this.category,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'barcode': barcode,
      'quantity': quantity,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'category': category,
      'total': total,
    };
  }

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      id: map['id'],
      productName: map['product_name'],
      barcode: map['barcode'],
      quantity: map['quantity'],
      purchasePrice:
          map['purchase_price'] is int
              ? (map['purchase_price'] as int).toDouble()
              : map['purchase_price'],
      salePrice:
          map['sale_price'] is int
              ? (map['sale_price'] as int).toDouble()
              : map['sale_price'],
      category: map['category'],
      total:
          map['total'] is int ? (map['total'] as int).toDouble() : map['total'],
    );
  }

  PurchaseInvoiceItem copyWith({
    int? id,
    String? productName,
    String? barcode,
    int? quantity,
    double? purchasePrice,
    double? salePrice,
    String? category,
    double? total,
  }) {
    return PurchaseInvoiceItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      category: category ?? this.category,
      total: total ?? this.total,
    );
  }
}
