import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sales_invoice.dart';

class PrintingService {
  // Singleton pattern for easier access
  static final PrintingService _instance = PrintingService._internal();
  factory PrintingService() => _instance;
  PrintingService._internal();

  /// Loads both Regular and Bold Arabic fonts
  Future<Map<String, pw.Font>> _loadFonts() async {
    pw.Font regular;
    pw.Font bold;

    try {
      print("🔄 Loading Arabic fonts...");
      final regularData = await rootBundle.load(
        "assets/fonts/Cairo-Regular.ttf",
      );
      final boldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

      regular = pw.Font.ttf(regularData);
      bold = pw.Font.ttf(boldData);
      print("✅ Loaded local fonts successfully");
    } catch (e) {
      print("⚠️ Local fonts failed: $e. Using Google Fonts fallback...");
      try {
        regular = await PdfGoogleFonts.cairoRegular();
        bold = await PdfGoogleFonts.cairoBold();
        print("✅ Loaded Google Fonts successfully");
      } catch (e2) {
        print("❌ Error loading fonts: $e2");
        regular = pw.Font.courier();
        bold = pw.Font.courier();
      }
    }
    return {'regular': regular, 'bold': bold};
  }

  /// Prints a Sales Invoice with Premium Design
  Future<void> printInvoice(SaleInvoice invoice) async {
    final fonts = await _loadFonts();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(
          base: fonts['regular'],
          bold: fonts['bold'],
          italic: fonts['regular'],
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // === HEADER ===
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 2)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "سوبر ماركت الأخوة", // Placeholder Shop Name
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "فاتورة مبيعات",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // === INVOICE INFO ===
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "رقم الفاتورة:",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "#${invoice.invoiceNumber}",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "التاريخ:",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      invoice.date,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                if (invoice.customerName?.isNotEmpty == true)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4),
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          "العميل: ",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          invoice.customerName!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 10),

                // === ITEMS HEADER ===
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          "الصنف",
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          "الكمية",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          "السعر",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          "الإجمالي",
                          textAlign: pw.TextAlign.end,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),

                // === ITEMS LIST ===
                ...invoice.items.map((item) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          width: 0.5,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.productName,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Row(
                          children: [
                            pw.Expanded(flex: 2, child: pw.SizedBox()),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                item.quantity.toString(),
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                item.price.toStringAsFixed(2),
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                item.total.toStringAsFixed(2),
                                textAlign: pw.TextAlign.end,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                      ],
                    ),
                  );
                }).toList(),

                pw.SizedBox(height: 10),

                // === TOTALS ===
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "إجمالي الفاتورة",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "${invoice.total.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (invoice.paidAmount > 0) ...[
                        pw.Divider(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "المدفوع",
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              invoice.paidAmount.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                      if (invoice.remainingAmount > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "المتبقي",
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              invoice.remainingAmount.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),
                pw.BarcodeWidget(
                  data: invoice.invoiceNumber,
                  width: 100,
                  height: 40,
                  barcode: pw.Barcode.code128(),
                  drawText: false,
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    "شكراً لزيارتكم",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Invoice_${invoice.invoiceNumber}',
    );
  }

  /// Prints a Statement (Customer/Supplier)
  Future<void> printStatement({
    required String title,
    required String entityName,
    required String dateRange,
    required List<StatementItem> items,
  }) async {
    final fonts = await _loadFonts();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(
          base: fonts['regular'],
          bold: fonts['bold'],
          italic: fonts['regular'],
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  title,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.Text(
                  "الاسم: $entityName",
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  "الفترة: $dateRange",
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 10),

                ...items.map((item) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              item.date,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              item.type,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                        if (item.description.isNotEmpty)
                          pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              item.description,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                        pw.Divider(
                          height: 4,
                          thickness: 0.5,
                          borderStyle: pw.BorderStyle.dashed,
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "${item.isCredit ? 'له' : 'عليه'}: ${item.amount.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color:
                                    item.isCredit
                                        ? PdfColors.green800
                                        : PdfColors.red800,
                              ),
                            ),
                            pw.Text(
                              "الرصيد: ${item.balance.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

                pw.SizedBox(height: 10),
                pw.Text(
                  "*** نهاية التقرير ***",
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Statement_$entityName',
    );
  }
}

// Helper model for Statement Items to keep the service generic
class StatementItem {
  final String date;
  final String type; // e.g., "فاتورة", "سداد"
  final String description;
  final double amount;
  final double balance;
  final bool isCredit; // True if payment/credit, False if invoice/debit

  StatementItem({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.balance,
    required this.isCredit,
  });
}
