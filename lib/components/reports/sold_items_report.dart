import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class SoldItemsReport extends StatelessWidget {
  final List<ProductReportData> data;

  const SoldItemsReport({super.key, required this.data});

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
                  "المنتجات التي تم بيعها",
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
                DataColumn(label: Text("الكمية المتبقية")),
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
                        DataCell(
                          Text(
                            item.quantity.toString(),
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.remaining?.toString() ?? "0",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
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
