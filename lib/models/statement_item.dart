import 'sales_invoice.dart';

class StatementItem {
  final String date;
  final String? invoiceNumber;
  final String type; // e.g., "فاتورة", "سداد", "مرتجع"
  final String description; // used for item details if any
  final double amount;
  final double balance;
  final bool isCredit; // True if payment(credit), False if invoice(debit)
  final bool isReturn; // True if return invoice
  final double? invoiceDiscount; // Optional invoice-level discount

  StatementItem({
    required this.date,
    this.invoiceNumber,
    required this.type,
    required this.description,
    required this.amount,
    required this.balance,
    required this.isCredit,
    this.isReturn = false,
    this.items,
    this.invoiceDiscount,
  });

  final List<SaleInvoiceItem>? items;
}
