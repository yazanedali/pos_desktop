class SalesReportData {
  final String date;
  final int invoices;
  final double total;

  SalesReportData({
    required this.date,
    required this.invoices,
    required this.total,
  });
}

class PurchaseReportData {
  final String date;
  final int invoices;
  final int items;
  final double total;

  PurchaseReportData({
    required this.date,
    required this.invoices,
    required this.items,
    required this.total,
  });
}

class ProfitReportData {
  final String date;
  final double sales;
  final double purchases;
  final double profit;

  ProfitReportData({
    required this.date,
    required this.sales,
    required this.purchases,
    required this.profit,
  });
}

class ProductReportData {
  final String name;
  final int quantity;
  final double revenue;
  final int? remaining;

  ProductReportData({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.remaining,
  });
}
