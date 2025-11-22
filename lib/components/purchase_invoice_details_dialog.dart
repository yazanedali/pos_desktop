import 'package:flutter/material.dart';
import '../models/purchase_invoice.dart';
import '../models/category.dart';

class PurchaseInvoiceDetailsDialog extends StatelessWidget {
  final PurchaseInvoice invoice;
  final List<Category> categories;
  final Function() onClose;

  const PurchaseInvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.categories,
    required this.onClose,
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
    return Directionality(
      textDirection: TextDirection.rtl, // <<< المهم هنا
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      "تفاصيل فاتورة الشراء",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // معلومات الفاتورة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem("التاريخ", invoice.date),
                      _buildInfoItem("الوقت", invoice.time),
                      _buildInfoItem("المورد", invoice.supplier),
                      _buildInfoItem(
                        "عدد المنتجات",
                        "${invoice.items.length} منتج",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "تفاصيل المنتجات",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("المنتج")),
                        DataColumn(label: Text("الباركود")),
                        DataColumn(label: Text("الفئة")),
                        DataColumn(label: Text("سعر الشراء")),
                        DataColumn(label: Text("سعر البيع")),
                        DataColumn(label: Text("الكمية")),
                        DataColumn(label: Text("الإجمالي")),
                      ],
                      rows:
                          invoice.items.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.productName)),
                                DataCell(Text(item.barcode)),
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
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${item.purchasePrice.toStringAsFixed(2)} شيكل",
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${item.salePrice.toStringAsFixed(2)} شيكل",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                                DataCell(Text(item.quantity.toString())),
                                DataCell(
                                  Text(
                                    "${item.total.toStringAsFixed(2)} شيكل",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "المبلغ الإجمالي:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${invoice.total.toStringAsFixed(2)} شيكل",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onClose,
                    child: const Text("إغلاق"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
