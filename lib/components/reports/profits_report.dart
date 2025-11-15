import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class ProfitsReport extends StatelessWidget {
  final List<ProfitReportData> data;

  const ProfitsReport({super.key, required this.data});

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
                Icon(Icons.attach_money, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "تقرير الأرباح",
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
                DataColumn(label: Text("المبيعات")),
                DataColumn(label: Text("المشتريات")),
                DataColumn(label: Text("صافي الربح")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.date)),
                        DataCell(
                          Text(
                            "${item.sales.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.purchases.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.profit.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
