class SupplierBalanceTransaction {
  final int? id;
  final int supplierId;
  final String transactionDate;
  final String transactionTime;
  final String description;
  final double debit; // المبلغ المدفوع للمورد
  final double credit; // المبلغ المدين به للمورد
  final double balance; // الرصيد بعد العملية
  final int? invoiceId;
  final int? paymentId;
  final String? createdAt;

  SupplierBalanceTransaction({
    this.id,
    required this.supplierId,
    required this.transactionDate,
    required this.transactionTime,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    required this.balance,
    this.invoiceId,
    this.paymentId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'transaction_date': transactionDate,
      'transaction_time': transactionTime,
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'invoice_id': invoiceId,
      'payment_id': paymentId,
      'created_at': createdAt,
    };
  }

  factory SupplierBalanceTransaction.fromMap(Map<String, dynamic> map) {
    return SupplierBalanceTransaction(
      id: map['id'],
      supplierId: map['supplier_id'],
      transactionDate: map['transaction_date'],
      transactionTime: map['transaction_time'],
      description: map['description'],
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num).toDouble(),
      invoiceId: map['invoice_id'],
      paymentId: map['payment_id'],
      createdAt: map['created_at'],
    );
  }

  // للعرض في الواجهة
  String get type {
    if (debit > 0) return 'دفعة';
    if (credit > 0) return 'دين';
    return 'معاملة';
  }

  double get amount {
    if (debit > 0) return debit;
    if (credit > 0) return credit;
    return 0.0;
  }
}
