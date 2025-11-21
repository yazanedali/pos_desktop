import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class PaymentTypeReport extends StatelessWidget {
  final List<PaymentTypeReportData> data;

  const PaymentTypeReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalAmount = data.fold(0.0, (sum, item) => sum + item.total);
    final totalCash = data.fold(0.0, (sum, item) => sum + item.cashTotal);
    final totalCredit = data.fold(0.0, (sum, item) => sum + item.creditTotal);

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
                Icon(Icons.payment, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "المبيعات حسب نوع الدفع",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الإحصائيات الإجمالية
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("إجمالي المبيعات", totalAmount, Colors.blue),
                    _buildStatItem("المبيعات النقدية", totalCash, Colors.green),
                    _buildStatItem(
                      "المبيعات الآجلة",
                      totalCredit,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            DataTable(
              columns: const [
                DataColumn(label: Text("التاريخ")),
                DataColumn(label: Text("الفواتير النقدية")),
                DataColumn(label: Text("المبلغ النقدي")),
                DataColumn(label: Text("الفواتير الآجلة")),
                DataColumn(label: Text("المبلغ الآجل")),
                DataColumn(label: Text("الإجمالي")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.date)),
                        DataCell(
                          Text(
                            item.cashInvoices.toString(),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.cashTotal.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.creditInvoices.toString(),
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.creditTotal.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
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

  Widget _buildStatItem(String title, double value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${value.toStringAsFixed(2)} شيكل",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
