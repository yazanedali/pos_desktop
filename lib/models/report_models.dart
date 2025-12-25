class SalesReportData {
  final String date;
  final int invoices;
  final double total;
  final double cashTotal;
  final double creditTotal;
  final int cashInvoices;
  final int creditInvoices;

  SalesReportData({
    required this.date,
    required this.invoices,
    required this.total,
    required this.cashTotal,
    required this.creditTotal,
    required this.cashInvoices,
    required this.creditInvoices,
  });
}

class PurchaseReportData {
  final String date;
  final int invoices;
  final double items;
  final double total;

  PurchaseReportData({
    required this.date,
    required this.invoices,
    required this.items,
    required this.total,
  });
}

// الموديل الحالي لديك:
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

// موديل جديد للربح الفعلي
// الموديل الجديد:
class ActualProfitReportData {
  final String date;
  final double sales;
  final double costOfGoodsSold; // تكلفة البضاعة المباعة
  final double actualProfit; // الربح الفعلي
  final double profitMargin; // هامش الربح %

  ActualProfitReportData({
    required this.date,
    required this.sales,
    required this.costOfGoodsSold,
    required this.actualProfit,
    required this.profitMargin,
  });
}

class ProductReportData {
  final String name;
  final double quantity;
  final double revenue;
  final double? remaining;
  ProductReportData({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.remaining,
  });
}

class OutstandingDebtData {
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final int invoicesCount;
  final double totalDebt;
  final double totalPaid;
  final double totalRemaining;
  final List<CustomerDebtDetail> debtDetails;

  OutstandingDebtData({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.invoicesCount,
    required this.totalDebt,
    required this.totalPaid,
    required this.totalRemaining,
    required this.debtDetails,
  });
}

class PaymentTypeReportData {
  final String date;
  final int invoices;
  final double total;
  final double cashTotal; // إجمالي قيمة الفواتير النقدية
  final double creditTotal; // إجمالي قيمة الفواتير الآجلة
  final int cashInvoices; // عدد الفواتير النقدية
  final int creditInvoices; // عدد الفواتير الآجلة
  final double totalPaid; // إجمالي المبلغ المدفوع (للمعلومة)
  final double totalDebt; // إجمالي المبلغ المتبقي (للمعلومة)

  PaymentTypeReportData({
    required this.date,
    required this.invoices,
    required this.total,
    required this.cashTotal,
    required this.creditTotal,
    required this.cashInvoices,
    required this.creditInvoices,
    this.totalPaid = 0.0,
    this.totalDebt = 0.0,
  });
}

class PaymentStatusReportData {
  final String paymentStatus;
  final int invoicesCount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;

  PaymentStatusReportData({
    required this.paymentStatus,
    required this.invoicesCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });
}

class PaymentRecordData {
  final int id;
  final int invoiceId;
  final String? invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final String paymentDate;
  final String paymentTime;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final String createdAt;

  PaymentRecordData({
    required this.id,
    required this.invoiceId,
    this.invoiceNumber,
    this.customerName,
    this.customerPhone,
    required this.paymentDate,
    required this.paymentTime,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
}

class CustomerDebtDetail {
  final int invoiceId;
  final String invoiceNumber;
  final String date;
  final String time;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String paymentType;
  final String paymentStatus;
  final String createdAt;

  CustomerDebtDetail({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.time,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentType,
    required this.paymentStatus,
    required this.createdAt,
  });
}
