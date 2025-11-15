import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class PurchasedItemsReport extends StatelessWidget {
  final List<ProductReportData> data;

  const PurchasedItemsReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "المنتجات التي تم شراؤها",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DataTable(
              columns: const [
                DataColumn(label: Text("المنتج")),
                DataColumn(label: Text("الكمية المشتراة")),
                DataColumn(label: Text("إجمالي التكلفة")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text(item.quantity.toString())),
                        DataCell(
                          Text(
                            "${item.revenue.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
