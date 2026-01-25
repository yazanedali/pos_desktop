// models/sales_invoice.dart

class SaleInvoice {
  final int? id;
  final String invoiceNumber;
  final String date;
  final String time;
  final double total;
  final double paidAmount;
  final double remainingAmount;
  final String cashier;
  final int? customerId;
  final String? customerName;
  final String paymentMethod;
  final String paymentType;
  final String paymentStatus;
  final double originalTotal;
  final String? notes;
  final String? createdAt;
  final bool isReturn; // <-- NEW
  final int? parentInvoiceId; // <-- NEW
  final List<SaleInvoiceItem> items; // <-- هون بتكون العناصر

  SaleInvoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.time,
    required this.total,
    required this.paidAmount,
    required this.remainingAmount,
    required this.cashier,
    this.customerId,
    this.customerName,
    required this.paymentMethod,
    required this.paymentType,
    required this.paymentStatus,
    required this.originalTotal,
    this.notes,
    this.createdAt,
    this.isReturn = false, // Default false
    this.parentInvoiceId,
    required this.items, // <-- مطلوبة
  });

  factory SaleInvoice.fromMap(Map<String, dynamic> map) {
    return SaleInvoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      cashier: map['cashier'] ?? '',
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      paymentMethod: map['payment_method'] ?? 'نقدي',
      paymentType: map['payment_type'] ?? 'نقدي',
      paymentStatus: map['payment_status'] ?? 'مدفوع',
      originalTotal: (map['original_total'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['created_at'],
      isReturn: (map['is_return'] as int?) == 1,
      parentInvoiceId: map['parent_invoice_id'],
      items: [], // <-- بتكون فارغة وبتملأ بعدين
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'date': date,
      'time': time,
      'total': total,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'cashier': cashier,
      'customer_id': customerId,
      'customer_name': customerName,
      'payment_method': paymentMethod,
      'payment_type': paymentType,
      'payment_status': paymentStatus,
      'original_total': originalTotal,
      'notes': notes,
      'created_at': createdAt,
      'is_return': isReturn ? 1 : 0,
      'parent_invoice_id': parentInvoiceId,
    };
  }
}

class SaleInvoiceItem {
  final int? id;
  final int invoiceId;
  final int? productId;
  final String productName;
  final double price;
  final double quantity; // <-- غيرت لـ double عشان يتوافق مع DB
  final double total;
  final double unitQuantity;
  final String unitName;
  final double costPrice; // <-- سعر التكلفة لحظة البيع
  final double discount; // خصم سطر العنصر (إن وُجد)

  SaleInvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
    this.unitQuantity = 1.0,
    required this.unitName,
    this.costPrice = 0.0, // <-- default
    this.discount = 0.0,
  });

  SaleInvoiceItem copyWith({
    double? quantity,
    double? total,
    double? costPrice,
    double? discount,
  }) {
    return SaleInvoiceItem(
      id: id,
      invoiceId: invoiceId,
      productId: productId,
      productName: productName,
      price: price,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      unitQuantity: unitQuantity,
      unitName: unitName,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
    );
  }

  factory SaleInvoiceItem.fromMap(Map<String, dynamic> map) {
    return SaleInvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'] ?? 0,
      productId: map['product_id'] ?? 0,
      productName: map['product_name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      unitQuantity: (map['unit_quantity'] as num?)?.toDouble() ?? 1.0,
      unitName: map['unit_name'] ?? 'حبة',
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0, // <-- read
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
      'unit_quantity': unitQuantity,
      'unit_name': unitName,
      'cost_price': costPrice, // <-- write
      'discount': discount,
    };
  }
}
