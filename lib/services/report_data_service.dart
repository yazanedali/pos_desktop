import '../models/report_models.dart';

class ReportDataService {
  static List<SalesReportData> getSalesReportData() {
    return [
      SalesReportData(date: "2024-12-01", invoices: 25, total: 5420.50),
      SalesReportData(date: "2024-12-02", invoices: 18, total: 3280.75),
      SalesReportData(date: "2024-12-03", invoices: 32, total: 7150.25),
      SalesReportData(date: "2024-12-04", invoices: 28, total: 6340.80),
      SalesReportData(date: "2024-12-05", invoices: 35, total: 8920.40),
    ];
  }

  static List<PurchaseReportData> getPurchaseReportData() {
    return [
      PurchaseReportData(
        date: "2024-12-01",
        invoices: 5,
        items: 45,
        total: 2150.00,
      ),
      PurchaseReportData(
        date: "2024-12-02",
        invoices: 3,
        items: 32,
        total: 1820.50,
      ),
      PurchaseReportData(
        date: "2024-12-03",
        invoices: 7,
        items: 58,
        total: 3240.75,
      ),
      PurchaseReportData(
        date: "2024-12-04",
        invoices: 4,
        items: 38,
        total: 1950.25,
      ),
      PurchaseReportData(
        date: "2024-12-05",
        invoices: 6,
        items: 52,
        total: 2780.90,
      ),
    ];
  }

  static List<ProfitReportData> getProfitReportData() {
    return [
      ProfitReportData(
        date: "2024-12-01",
        sales: 5420.50,
        purchases: 2150.00,
        profit: 3270.50,
      ),
      ProfitReportData(
        date: "2024-12-02",
        sales: 3280.75,
        purchases: 1820.50,
        profit: 1460.25,
      ),
      ProfitReportData(
        date: "2024-12-03",
        sales: 7150.25,
        purchases: 3240.75,
        profit: 3909.50,
      ),
      ProfitReportData(
        date: "2024-12-04",
        sales: 6340.80,
        purchases: 1950.25,
        profit: 4390.55,
      ),
      ProfitReportData(
        date: "2024-12-05",
        sales: 8920.40,
        purchases: 2780.90,
        profit: 6139.50,
      ),
    ];
  }

  static List<ProductReportData> getTopSellingProducts() {
    return [
      ProductReportData(name: "كوكا كولا", quantity: 125, revenue: 312.50),
      ProductReportData(name: "شيبس", quantity: 98, revenue: 147.00),
      ProductReportData(name: "شوكولاتة", quantity: 87, revenue: 261.00),
      ProductReportData(name: "عصير برتقال", quantity: 76, revenue: 304.00),
      ProductReportData(name: "قهوة", quantity: 65, revenue: 325.00),
    ];
  }

  static List<ProductReportData> getPurchasedItems() {
    return [
      ProductReportData(name: "كوكا كولا", quantity: 200, revenue: 400.00),
      ProductReportData(name: "شيبس", quantity: 150, revenue: 225.00),
      ProductReportData(name: "شوكولاتة", quantity: 120, revenue: 240.00),
      ProductReportData(name: "عصير برتقال", quantity: 100, revenue: 300.00),
      ProductReportData(name: "قهوة", quantity: 80, revenue: 240.00),
    ];
  }

  static List<ProductReportData> getSoldItems() {
    return [
      ProductReportData(
        name: "كوكا كولا",
        quantity: 125,
        revenue: 312.50,
        remaining: 75,
      ),
      ProductReportData(
        name: "شيبس",
        quantity: 98,
        revenue: 147.00,
        remaining: 52,
      ),
      ProductReportData(
        name: "شوكولاتة",
        quantity: 87,
        revenue: 261.00,
        remaining: 33,
      ),
      ProductReportData(
        name: "عصير برتقال",
        quantity: 76,
        revenue: 304.00,
        remaining: 24,
      ),
      ProductReportData(
        name: "قهوة",
        quantity: 65,
        revenue: 325.00,
        remaining: 15,
      ),
    ];
  }
}
