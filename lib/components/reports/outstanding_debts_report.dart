import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class OutstandingDebtsReport extends StatelessWidget {
  final List<OutstandingDebtData> data;

  const OutstandingDebtsReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalDebt = data.fold(0.0, (sum, item) => sum + item.totalRemaining);
    final totalCustomers = data.length;

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
                Icon(Icons.money_off, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "الديون المستحقة",
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
                    Column(
                      children: [
                        Text(
                          "إجمالي الديون",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${totalDebt.toStringAsFixed(2)} شيكل",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          "عدد العملاء",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalCustomers.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            DataTable(
              columns: const [
                DataColumn(label: Text("اسم العميل")),
                DataColumn(label: Text("الهاتف")),
                DataColumn(label: Text("عدد الفواتير")),
                DataColumn(label: Text("إجمالي الدين")),
                DataColumn(label: Text("المبلغ المدفوع")),
                DataColumn(label: Text("المتبقي")),
              ],
              rows:
                  data.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.customerPhone ?? "-",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        DataCell(Text(item.invoicesCount.toString())),
                        DataCell(
                          Text(
                            "${item.totalDebt.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.totalPaid.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.totalRemaining.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
