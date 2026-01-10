class FinancialSummary {
  final double totalSales;
  final double totalCollected; // Cash + Bank + etc (Actual money in)
  final double totalReceivables; // Debts (Money outside)
  final double totalPayables; // Wallets (Money we owe to customers)
  final double totalStockValue; // Value of current inventory
  final double
  netCashFlow; // Collected - Payables (rough estimate of available liquid)

  FinancialSummary({
    required this.totalSales,
    required this.totalCollected,
    required this.totalReceivables,
    required this.totalPayables,
    required this.totalStockValue,
    required this.netCashFlow,
  });
}

class PaymentMethodStat {
  final String method;
  final double totalAmount;
  final int count;

  PaymentMethodStat({
    required this.method,
    required this.totalAmount,
    required this.count,
  });
}

class DebtorStat {
  final int customerId;
  final String customerName;
  final double totalDebt;
  final String lastTransactionDate;

  DebtorStat({
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
    required this.lastTransactionDate,
  });
}

class WalletStat {
  final int customerId;
  final String customerName;
  final double balance; // Positive means store owes customer

  WalletStat({
    required this.customerId,
    required this.customerName,
    required this.balance,
  });
}

class RealProfitStat {
  final double totalSales;
  final double totalCostOfGoods; // Based on sales
  final double grossProfit; // Sales - COGS
  final double collectionRatio; // Collected / Sales
  final double
  realizedProfit; // GrossProfit * CollectionRatio (The star metric)

  RealProfitStat({
    required this.totalSales,
    required this.totalCostOfGoods,
    required this.grossProfit,
    required this.collectionRatio,
    required this.realizedProfit,
  });
}
