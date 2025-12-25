class DebtorInfo {
  final int customerId;
  final String customerName;
  final double totalDebt;
  final double walletBalance; // <--

  DebtorInfo({
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
    this.walletBalance = 0.0,
  });

  factory DebtorInfo.fromMap(Map<String, dynamic> map) {
    final totalDebtValue = (map['totalDebt'] as num? ?? 0).toDouble();
    final walletBalanceValue = (map['walletBalance'] as num? ?? 0).toDouble();

    return DebtorInfo(
      customerId: map['customerId'],
      customerName: map['customerName'],
      totalDebt: totalDebtValue,
      walletBalance: walletBalanceValue,
    );
  }
}
