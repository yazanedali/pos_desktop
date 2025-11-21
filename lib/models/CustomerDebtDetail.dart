class PaymentStatistics {
  final int cashInvoices;
  final double cashTotal;
  final int creditInvoices;
  final double creditTotal;
  final int paymentRecordsCount;
  final double paymentRecordsTotal;

  PaymentStatistics({
    required this.cashInvoices,
    required this.cashTotal,
    required this.creditInvoices,
    required this.creditTotal,
    required this.paymentRecordsCount,
    required this.paymentRecordsTotal,
  });
}
