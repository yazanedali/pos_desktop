import 'package:flutter/material.dart';
import '../models/purchase_invoice.dart';
import '../models/category.dart';
import '../dialogs/purchase_return_dialog.dart';

class PurchaseInvoiceDetailsDialog extends StatelessWidget {
  final PurchaseInvoice invoice;
  final List<Category> categories;
  final Function() onClose;
  final Function() onPrint;

  const PurchaseInvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.categories,
    required this.onClose,
    required this.onPrint,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }

  Color _getCategoryColor(String categoryName) {
    final category = categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => Category(id: 0, name: "", color: "#6B7280"),
    );
    return _hexToColor(category.color);
  }

  @override
  Widget build(BuildContext context) {
    // المعادلة المحاسبية:
    // الصافي النهائي (المخزن) = (مجموع صافي البنود) - الخصم العام
    // إذن: مجموع صافي البنود = الصافي النهائي + الخصم العام
    final double subtotalOfItems = invoice.total + invoice.discount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          // وسعنا العرض شوي عشان الأعمدة الكثيرة
          constraints: const BoxConstraints(maxHeight: 750, maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. رأس الفاتورة
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Colors.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "كشف تفاصيل فاتورة",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontFamily: 'Courier', // خط يشبه الفواتير
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            invoice.paymentStatus == 'مدفوع'
                                ? Colors.green[50]
                                : Colors.orange[50],
                        border: Border.all(
                          color:
                              invoice.paymentStatus == 'مدفوع'
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        invoice.paymentStatus,
                        style: TextStyle(
                          color:
                              invoice.paymentStatus == 'مدفوع'
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. معلومات المورد والتاريخ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem(
                        Icons.calendar_today,
                        "التاريخ",
                        invoice.date,
                      ),
                      _buildInfoItem(Icons.access_time, "الوقت", invoice.time),
                      _buildInfoItem(
                        Icons.business,
                        "المورد",
                        invoice.supplier,
                      ),
                      _buildInfoItem(
                        Icons.shopping_bag_outlined,
                        "البنود",
                        "${invoice.items.length}",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "بنود الفاتورة:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // 3. جدول البيانات المفصل (محاسبي)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.blue[50],
                        ),
                        columnSpacing: 20, // مسافة بين الأعمدة
                        columns: const [
                          DataColumn(label: Text("المنتج")),
                          DataColumn(label: Text("الفئة")),
                          DataColumn(label: Text("الكمية")),
                          DataColumn(label: Text("سعر الوحدة")),
                          // الأعمدة المحاسبية الجديدة
                          DataColumn(label: Text("الإجمالي (قبل)")),
                          DataColumn(
                            label: Text(
                              "قيمة الخصم",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "الصافي (بعد)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows:
                            invoice.items.map((item) {
                              // الحسابات لكل سطر
                              double grossTotal =
                                  item.quantity *
                                  item.purchasePrice; // الإجمالي قبل الخصم

                              return DataRow(
                                cells: [
                                  // المنتج والباركود
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (item.barcode.isNotEmpty)
                                          Text(
                                            item.barcode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // الفئة (مع الألوان)
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(item.category),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item.category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(item.quantity.toString())),
                                  DataCell(
                                    Text(
                                      "${item.purchasePrice.toStringAsFixed(2)}",
                                    ),
                                  ),

                                  // الإجمالي قبل الخصم
                                  DataCell(
                                    Text(
                                      "${grossTotal.toStringAsFixed(2)}",
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ),

                                  // قيمة الخصم
                                  DataCell(
                                    Text(
                                      item.discount > 0
                                          ? "-${item.discount.toStringAsFixed(2)}"
                                          : "-",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight:
                                            item.discount > 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),

                                  // الصافي النهائي للسطر
                                  DataCell(
                                    Text(
                                      "${item.total.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. ملخص الحسابات (Footer) - تصميم محاسبي
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // مجموع البنود
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "مجموع البنود (بعد خصومات الأسطر):",
                            style: TextStyle(fontSize: 15),
                          ),
                          Text(
                            "${subtotalOfItems.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // الخصم الكلي للفاتورة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "خصم إضافي على الفاتورة (كلي):",
                            style: TextStyle(fontSize: 15, color: Colors.red),
                          ),
                          Text(
                            "- ${invoice.discount.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(thickness: 1),
                      ),

                      // المجموع النهائي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "الإجمالي النهائي المستحق:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${invoice.total.toStringAsFixed(2)} شيكل",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 5. أزرار الإجراءات
                Row(
                  children: [
                    // زر استرجاع (يظهر فقط إذا لم تكن الفاتورة مرتجع)
                    if (!invoice.isReturn) ...[
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => PurchaseReturnDialog(
                                      originalInvoice: invoice,
                                      onReturnCompleted: () {
                                        // نغلق الديالوج الحالي (تفاصيل الفاتورة) لنعود للقائمة وتحديثها
                                        // أو يمكننا فقط استدعاء onClose لتحديث الأب
                                        onClose();
                                      },
                                    ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.assignment_return, size: 20),
                            label: const Text(
                              "مرتجع شراء",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // زر الطباعة
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton.icon(
                          onPressed: onPrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.print_outlined, size: 20),
                          label: const Text(
                            "طباعة الفاتورة",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // زر الإغلاق
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: onClose,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.black,
                          ),
                          label: const Text(
                            "إغلاق",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
