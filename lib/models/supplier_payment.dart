class SupplierPayment {
  final int? id;
  final int supplierId;
  final String paymentDate;
  final String paymentTime;
  final double amount;
  final String paymentType; // نقدي، تحويل بنكي، شيك، إلخ
  final String? notes;
  final int? invoiceId; // يمكن ربطها بفاتورة محددة
  final bool isOpeningBalance;
  final String? createdAt;

  SupplierPayment({
    this.id,
    required this.supplierId,
    required this.paymentDate,
    required this.paymentTime,
    required this.amount,
    this.paymentType = 'نقدي',
    this.notes,
    this.invoiceId,
    this.isOpeningBalance = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'payment_date': paymentDate,
      'payment_time': paymentTime,
      'amount': amount,
      'payment_type': paymentType,
      'notes': notes,
      'invoice_id': invoiceId,
      'is_opening_balance': isOpeningBalance ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'],
      supplierId: map['supplier_id'],
      paymentDate: map['payment_date'],
      paymentTime: map['payment_time'],
      amount: (map['amount'] as num).toDouble(),
      paymentType: map['payment_type'] ?? 'نقدي',
      notes: map['notes'],
      invoiceId: map['invoice_id'],
      isOpeningBalance: (map['is_opening_balance'] as int?) == 1,
      createdAt: map['created_at'],
    );
  }
}
