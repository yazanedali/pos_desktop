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

  // الرصيد الصافي: (له - عليه)
  // القيمة الموجبة تعني أن للزبون رصيد (له)
  // القيمة السالبة تعني أن على الزبون دين (عليه)
  double get netBalance => walletBalance - totalDebt;

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
