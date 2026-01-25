import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sales_invoice.dart';
import '../models/purchase_invoice.dart';
import '../models/daily_closing.dart';
import '../models/statement_item.dart';

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
      final regularData = await rootBundle.load(
        "assets/fonts/Cairo-Regular.ttf",
      );
      final boldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");

      regular = pw.Font.ttf(regularData);
      bold = pw.Font.ttf(boldData);
    } catch (e) {
      try {
        regular = await PdfGoogleFonts.cairoRegular();
        bold = await PdfGoogleFonts.cairoBold();
      } catch (e2) {
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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(
          base: fonts['regular'],
          bold: fonts['bold'],
          italic: fonts['regular'],
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        build: (pw.Context context) {
          return [
            pw.Directionality(
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
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
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
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
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
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Invoice_${invoice.invoiceNumber}',
    );
  }

  /// Prints a Purchase Invoice with Premium Design
  Future<void> printPurchaseInvoice(PurchaseInvoice invoice) async {
    final fonts = await _loadFonts();
    final doc = pw.Document();

    // حساب الإجمالي قبل الخصم
    final double subtotal = invoice.total + invoice.discount;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(
          base: fonts['regular'],
          bold: fonts['bold'],
          italic: fonts['regular'],
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        build: (pw.Context context) {
          return [
            pw.Directionality(
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
                          "سوبر ماركت الأخوة",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "فاتورة مشتريات",
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
                        "${invoice.date} - ${invoice.time}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
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
                          "المورد: ",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          invoice.supplier,
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
                    // حساب الإجمالي قبل الخصم للبند
                    final itemGrossTotal = item.quantity * item.purchasePrice;

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
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (item.barcode.isNotEmpty)
                            pw.Text(
                              'الباركود: ${item.barcode}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  'الفئة: ${item.category}',
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                              ),
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
                                  item.purchasePrice.toStringAsFixed(2),
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    if (item.discount > 0) ...[
                                      pw.Text(
                                        itemGrossTotal.toStringAsFixed(2),
                                        style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.grey600,
                                          decoration:
                                              pw.TextDecoration.lineThrough,
                                        ),
                                      ),
                                      pw.Text(
                                        '-${item.discount.toStringAsFixed(2)}',
                                        style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.red,
                                        ),
                                      ),
                                    ],
                                    pw.Text(
                                      item.total.toStringAsFixed(2),
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blue800,
                                      ),
                                    ),
                                  ],
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
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(
                        width: 1.5,
                        color: PdfColors.blue800,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        // مجموع البنود قبل الخصومات
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "مجموع البنود (قبل الخصم)",
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              (subtotal + invoice.discount).toStringAsFixed(2),
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),

                        // الخصومات الجزئية (على البنود)
                        if (invoice.items.any((item) => item.discount > 0)) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                "خصومات البنود (جزئي)",
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.orange800,
                                ),
                              ),
                              pw.Text(
                                "- ${invoice.items.fold<double>(0, (sum, item) => sum + item.discount).toStringAsFixed(2)}",
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.orange800,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // الخصم الكلي على الفاتورة
                        if (invoice.discount > 0) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                "خصم إضافي (كلي)",
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red800,
                                ),
                              ),
                              pw.Text(
                                "- ${invoice.discount.toStringAsFixed(2)}",
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red800,
                                ),
                              ),
                            ],
                          ),
                        ],

                        pw.Divider(height: 6, thickness: 1),

                        // الإجمالي النهائي
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "الإجمالي النهائي",
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "${invoice.total.toStringAsFixed(2)} ش",
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),

                        // معلومات الدفع
                        if (invoice.paidAmount > 0 ||
                            invoice.remainingAmount > 0) ...[
                          pw.Divider(height: 6, thickness: 0.5),
                          if (invoice.paidAmount > 0)
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  "المدفوع",
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.green800,
                                  ),
                                ),
                                pw.Text(
                                  invoice.paidAmount.toStringAsFixed(2),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.green800,
                                  ),
                                ),
                              ],
                            ),
                          if (invoice.remainingAmount > 0) ...[
                            pw.SizedBox(height: 3),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  "المتبقي",
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.orange800,
                                  ),
                                ),
                                pw.Text(
                                  invoice.remainingAmount.toStringAsFixed(2),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.orange800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  // حالة الدفع
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color:
                          invoice.paymentStatus == 'مدفوع'
                              ? PdfColors.green50
                              : PdfColors.orange50,
                      border: pw.Border.all(
                        color:
                            invoice.paymentStatus == 'مدفوع'
                                ? PdfColors.green
                                : PdfColors.orange,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'حالة الدفع: ${invoice.paymentStatus}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color:
                              invoice.paymentStatus == 'مدفوع'
                                  ? PdfColors.green900
                                  : PdfColors.orange900,
                        ),
                      ),
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
                      "تم استلام البضاعة بحالة جيدة",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      "التوقيع: _______________",
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'PurchaseInvoice_${invoice.invoiceNumber}',
    );
  }

  /// Prints a Statement (Customer/Supplier)
  Future<void> printStatement({
    required String title,
    required String entityName,
    required String dateRange,
    required List<StatementItem> items,
    bool isSupplier = false,
  }) async {
    final fonts = await _loadFonts();
    final doc = pw.Document();

    // Deduplicate duplicate lines anywhere (same date,type,invoiceNumber,amount,description)
    final List<StatementItem> renderItems = [];
    final Set<String> seenKeys = {};
    for (var it in items) {
      String key;
      if (it.invoiceNumber != null && it.invoiceNumber!.isNotEmpty) {
        // Deduplicate primarily by invoice number when available
        key = '${it.date}|${it.type}|INV:${it.invoiceNumber}|${it.amount}';
      } else {
        key =
            '${it.date}|${it.type}|${it.invoiceNumber ?? ''}|${it.amount}|${it.description}';
      }
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      renderItems.add(it);
    }

    // Calculate Summary from deduped list
    double totalSales = 0;
    double totalPayments = 0;
    double totalReturns = 0;
    for (var item in renderItems) {
      if (item.isReturn) {
        totalReturns += item.amount;
      } else if (item.isCredit) {
        if (isSupplier) {
          totalSales += item.amount;
        } else {
          totalPayments += item.amount;
        }
      } else {
        if (isSupplier) {
          totalPayments += item.amount;
        } else {
          totalSales += item.amount;
        }
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(
          base: fonts['regular'],
          bold: fonts['bold'],
          italic: fonts['regular'],
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        build: (pw.Context context) {
          return [
            pw.Directionality(
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
                          "سوبر ماركت الأخوة",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // === INFO ===
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "الاسم: $entityName",
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "التاريخ: ${DateTime.now().toString().split(' ')[0]}",
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "من: ${dateRange.split('إلى')[0].replaceAll('من', '').trim()}",
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                                if (dateRange.contains('إلى'))
                                  pw.Text(
                                    "إلى: ${dateRange.split('إلى')[1].trim()}",
                                    style: const pw.TextStyle(fontSize: 9),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // === ITEMS HEADER ===
                  pw.Container(
                    color: PdfColors.grey200,
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 1,
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            "التاريخ/رقم",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 3, // More space for details
                          child: pw.Text(
                            "البيان/التفاصيل",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            "المبلغ",
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            "الرصيد",
                            textAlign: pw.TextAlign.end,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 4),

                  // === ITEMS LIST ===
                  ...renderItems.map((item) {
                    final sanitizedDescription =
                        item.invoiceNumber != null
                            ? item.description
                                .replaceAll(
                                  RegExp(RegExp.escape(item.invoiceNumber!)),
                                  '',
                                )
                                .replaceAll(RegExp(r"[#:]"), '')
                                .trim()
                            : item.description;
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 6),
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
                          // Row 1: Date | Type | Amount | Balance
                          pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.date,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    if (item.invoiceNumber != null &&
                                        !item.description.contains(
                                          item.invoiceNumber!,
                                        ))
                                      pw.Text(
                                        "#${item.invoiceNumber}",
                                        style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.grey700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 3,
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.type,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                        color:
                                            item.isReturn
                                                ? PdfColors.red800
                                                : PdfColors.black,
                                      ),
                                    ),
                                    // description already rendered above (sanitized)
                                    if (item.invoiceDiscount != null &&
                                        item.invoiceDiscount! > 0)
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.only(
                                          top: 2,
                                        ),
                                        child: pw.Text(
                                          'خصم الفاتورة: -${item.invoiceDiscount!.toStringAsFixed(2)}',
                                          style: pw.TextStyle(
                                            fontSize: 8,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.red800,
                                          ),
                                        ),
                                      ),
                                    if (item.items != null &&
                                        item.items!.isNotEmpty)
                                      pw.Container(
                                        margin: const pw.EdgeInsets.only(
                                          top: 2,
                                          right: 2,
                                        ),
                                        padding: const pw.EdgeInsets.all(2),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.grey50,
                                          border: pw.Border.all(
                                            color: PdfColors.grey300,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: pw.Column(
                                          children: [
                                            // Table Header
                                            pw.Row(
                                              children: [
                                                pw.Expanded(
                                                  flex: 3,
                                                  child: pw.Text(
                                                    "الصنف",
                                                    style: pw.TextStyle(
                                                      fontSize: 5,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: PdfColors.grey800,
                                                    ),
                                                  ),
                                                ),
                                                pw.Expanded(
                                                  flex: 1,
                                                  child: pw.Text(
                                                    "السعر",
                                                    textAlign:
                                                        pw.TextAlign.center,
                                                    style: pw.TextStyle(
                                                      fontSize: 5,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: PdfColors.grey800,
                                                    ),
                                                  ),
                                                ),
                                                pw.Expanded(
                                                  flex: 1,
                                                  child: pw.Text(
                                                    "العدد",
                                                    textAlign:
                                                        pw.TextAlign.center,
                                                    style: pw.TextStyle(
                                                      fontSize: 5,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: PdfColors.grey800,
                                                    ),
                                                  ),
                                                ),
                                                pw.Expanded(
                                                  flex: 1,
                                                  child: pw.Text(
                                                    "الإجمالي",
                                                    textAlign:
                                                        pw.TextAlign.center,
                                                    style: pw.TextStyle(
                                                      fontSize: 5,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: PdfColors.grey800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            pw.Divider(
                                              height: 2,
                                              color: PdfColors.grey300,
                                            ),
                                            ...item.items!.map(
                                              (prod) => pw.Column(
                                                crossAxisAlignment:
                                                    pw
                                                        .CrossAxisAlignment
                                                        .stretch,
                                                children: [
                                                  pw.Row(
                                                    children: [
                                                      pw.Expanded(
                                                        flex: 3,
                                                        child: pw.Text(
                                                          prod.productName,
                                                          style:
                                                              const pw.TextStyle(
                                                                fontSize: 5,
                                                              ),
                                                        ),
                                                      ),
                                                      pw.Expanded(
                                                        flex: 1,
                                                        child: pw.Text(
                                                          prod.price
                                                              .toStringAsFixed(
                                                                1,
                                                              ),
                                                          textAlign:
                                                              pw
                                                                  .TextAlign
                                                                  .center,
                                                          style:
                                                              const pw.TextStyle(
                                                                fontSize: 5,
                                                              ),
                                                        ),
                                                      ),
                                                      pw.Expanded(
                                                        flex: 1,
                                                        child: pw.Text(
                                                          prod.quantity
                                                              .toStringAsFixed(
                                                                1,
                                                              ),
                                                          textAlign:
                                                              pw
                                                                  .TextAlign
                                                                  .center,
                                                          style:
                                                              const pw.TextStyle(
                                                                fontSize: 5,
                                                              ),
                                                        ),
                                                      ),
                                                      pw.Expanded(
                                                        flex: 1,
                                                        child: pw.Text(
                                                          prod.total
                                                              .toStringAsFixed(
                                                                1,
                                                              ),
                                                          textAlign:
                                                              pw
                                                                  .TextAlign
                                                                  .center,
                                                          style:
                                                              const pw.TextStyle(
                                                                fontSize: 5,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (prod.discount > 0)
                                                    pw.Container(
                                                      alignment:
                                                          pw
                                                              .Alignment
                                                              .centerRight,
                                                      padding:
                                                          const pw.EdgeInsets.only(
                                                            top: 2,
                                                            right: 2,
                                                          ),
                                                      child: pw.Text(
                                                        'خصم جزئي: ${prod.discount.toStringAsFixed(2)}',
                                                        style: pw.TextStyle(
                                                          fontSize: 7,
                                                          fontWeight:
                                                              pw
                                                                  .FontWeight
                                                                  .bold,
                                                          color:
                                                              PdfColors.red800,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (sanitizedDescription.isNotEmpty)
                                      pw.Text(
                                        sanitizedDescription,
                                        style: const pw.TextStyle(
                                          fontSize: 7,
                                          color: PdfColors.grey700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  item.amount.toStringAsFixed(2),
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color:
                                        (isSupplier
                                                    ? !item.isCredit
                                                    : item.isCredit) ||
                                                item.isReturn
                                            ? PdfColors
                                                .red800 // Credit/Return (Negative impact on debt)
                                            : PdfColors
                                                .black, // Sales (Positive debt)
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  item.balance.toStringAsFixed(2),
                                  textAlign: pw.TextAlign.end,
                                  style: pw.TextStyle(
                                    fontSize: 8,
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

                  // === SUMMARY FOOTER ===
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(width: 1),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(5),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow(
                          isSupplier ? "إجمالي المشتريات" : "إجمالي المبيعات",
                          totalSales,
                        ),
                        _buildSummaryRow(
                          "إجمالي المرتجعات",
                          totalReturns,
                          isNegative: true,
                        ),
                        _buildSummaryRow(
                          "إجمالي المدفوعات",
                          totalPayments,
                          isNegative: true,
                        ),
                        // إجمالي خصم الفواتير (إن وُجد)
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "إجمالي خصم الفواتير",
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.red800,
                              ),
                            ),
                            pw.Text(
                              "- ${renderItems.fold<double>(0, (s, it) => s + (it.invoiceDiscount ?? 0)).toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.red800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.Divider(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "الرصيد النهائي",
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              items.isNotEmpty
                                  ? items.last.balance.toStringAsFixed(2)
                                  : "0.00",
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text(
                      "التوقيع: .....................",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Statement_$entityName',
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    double value, {
    bool isNegative = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            "${isNegative ? '-' : ''}${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontSize: 9,
              color: isNegative ? PdfColors.red800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Prints a Shift Closing Report
  Future<void> printShiftClosing(DailyClosing closing) async {
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
                  "تقرير إغلاق وردية",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),

                // Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "التاريخ:",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "${closing.closingDate} ${closing.closingTime}",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                if (closing.cashierName != null)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "الكاشير:",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "${closing.cashierName}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),

                pw.SizedBox(height: 10),

                // Financials
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _buildPrintRow("رصيد الافتتاح", closing.openingCash),
                      _buildPrintRow(
                        "المبيعات النقدية",
                        closing.totalSalesCash,
                      ),
                      _buildPrintRow(
                        "المصروفات",
                        closing.totalExpenses,
                        isNegative: true,
                      ),
                      pw.Divider(),
                      _buildPrintRow(
                        "المتوقع في الدرج",
                        closing.expectedCash,
                        isBold: true,
                      ),
                      _buildPrintRow(
                        "الفعلي (الجرد)",
                        closing.actualCash,
                        isBold: true,
                      ),
                      pw.Divider(),
                      _buildPrintRow(
                        "الفارق",
                        closing.difference,
                        isBold: true,
                        color:
                            closing.difference == 0
                                ? PdfColors.green800
                                : (closing.difference > 0
                                    ? PdfColors.blue800
                                    : PdfColors.red800),
                      ),
                    ],
                  ),
                ),

                if (closing.notes != null && closing.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "ملاحظات:",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    closing.notes!,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],

                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    "التوقيع: .....................",
                    style: const pw.TextStyle(fontSize: 10),
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
      name: 'ShiftClosing_${closing.closingDate}',
    );
  }

  pw.Widget _buildPrintRow(
    String label,
    double value, {
    bool isBold = false,
    bool isNegative = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            "${isNegative ? '-' : ''}${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
