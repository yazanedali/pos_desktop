import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class TopSellingReport extends StatelessWidget {
  final List<ProductReportData> data;

  const TopSellingReport({super.key, required this.data});

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
                Icon(Icons.trending_up, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "المنتجات الأكثر مبيعاً",
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
                DataColumn(label: Text("الكمية المباعة")),
                DataColumn(label: Text("إجمالي الإيرادات")),
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
                            style: const TextStyle(color: Colors.blue),
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
