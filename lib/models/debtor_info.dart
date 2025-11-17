class DebtorInfo {
  final int customerId;
  final String customerName;
  final double totalDebt;

  DebtorInfo({
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
  });

  factory DebtorInfo.fromMap(Map<String, dynamic> map) {
    final totalDebtValue = (map['totalDebt'] as num? ?? 0).toDouble();

    return DebtorInfo(
      customerId: map['customerId'],
      customerName: map['customerName'],
      totalDebt: totalDebtValue,
    );
  }
}
