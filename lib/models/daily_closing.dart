class DailyClosing {
  final int? id;
  final String closingDate;
  final String closingTime;
  final String? cashierName;
  final double openingCash;
  final double totalSalesCash;
  final double totalExpenses;
  final double
  totalDebtCollected; // For future use if collecting debt is tracked in cash_movements
  final double expectedCash;
  final double actualCash;
  final double difference;
  final String? notes;
  final String createdAt;

  DailyClosing({
    this.id,
    required this.closingDate,
    required this.closingTime,
    this.cashierName,
    required this.openingCash,
    required this.totalSalesCash,
    required this.totalExpenses,
    this.totalDebtCollected = 0.0,
    required this.expectedCash,
    required this.actualCash,
    required this.difference,
    this.notes,
    required this.createdAt,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'closing_date': closingDate,
      'closing_time': closingTime,
      'cashier_name': cashierName,
      'opening_cash': openingCash,
      'total_sales_cash': totalSalesCash,
      'total_expenses': totalExpenses,
      'total_debt_collected': totalDebtCollected,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'difference': difference,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  // Convert from Map
  factory DailyClosing.fromMap(Map<String, dynamic> map) {
    return DailyClosing(
      id: map['id'],
      closingDate: map['closing_date'],
      closingTime: map['closing_time'],
      cashierName: map['cashier_name'],
      openingCash: map['opening_cash']?.toDouble() ?? 0.0,
      totalSalesCash: map['total_sales_cash']?.toDouble() ?? 0.0,
      totalExpenses: map['total_expenses']?.toDouble() ?? 0.0,
      totalDebtCollected: map['total_debt_collected']?.toDouble() ?? 0.0,
      expectedCash: map['expected_cash']?.toDouble() ?? 0.0,
      actualCash: map['actual_cash']?.toDouble() ?? 0.0,
      difference: map['difference']?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}
