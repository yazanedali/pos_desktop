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
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      supplier: map['supplier'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      items: [],
      total: (map['total'] as num).toDouble(), // <-- التحويل الآمن
      createdAt: map['created_at'] as String?,
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
  final double quantity; // <-- غير من int إلى double
  final double purchasePrice;
  final double salePrice;
  final String category;
  final double total;

  PurchaseInvoiceItem({
    this.id,
    required this.productName,
    required this.barcode,
    required this.quantity, // <-- غير من int إلى double
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
      'quantity': quantity, // <-- الآن يتوافق مع قاعدة البيانات
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'category': category,
      'total': total,
    };
  }

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      id: map['id'] as int?,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String,
      quantity: (map['quantity'] as num).toDouble(), // <-- التحويل الآمن
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      category: map['category'] as String,
      total: (map['total'] as num).toDouble(),
    );
  }

  PurchaseInvoiceItem copyWith({
    int? id,
    String? productName,
    String? barcode,
    double? quantity, // <-- غير من int إلى double
    double? purchasePrice,
    double? salePrice,
    String? category,
    double? total,
  }) {
    return PurchaseInvoiceItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity, // <-- غير من int إلى double
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      category: category ?? this.category,
      total: total ?? this.total,
    );
  }
}
