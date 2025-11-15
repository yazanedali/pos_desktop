import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class SalesReport extends StatelessWidget {
  final List<SalesReportData> data;

  const SalesReport({super.key, required this.data});

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
                  "تقرير المبيعات",
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
                DataColumn(label: Text("التاريخ")),
                DataColumn(label: Text("عدد الفواتير")),
                DataColumn(label: Text("إجمالي المبيعات")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.date)),
                        DataCell(Text(item.invoices.toString())),
                        DataCell(
                          Text(
                            "${item.total.toStringAsFixed(2)} شيكل",
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
          ],
        ),
      ),
    );
  }
}
