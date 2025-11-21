import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class PaymentStatusReport extends StatelessWidget {
  final List<PaymentStatusReportData> data;

  const PaymentStatusReport({super.key, required this.data});

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
                Icon(Icons.account_balance_wallet, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "تقرير حالة السداد",
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
                DataColumn(label: Text("حالة السداد")),
                DataColumn(label: Text("عدد الفواتير")),
                DataColumn(label: Text("المبلغ الإجمالي")),
                DataColumn(label: Text("المبلغ المدفوع")),
                DataColumn(label: Text("المبلغ المتبقي")),
              ],
              rows:
                  data.map((item) {
                    Color statusColor = Colors.green;
                    if (item.paymentStatus == 'جزئي') {
                      statusColor = Colors.orange;
                    } else if (item.paymentStatus == 'غير مدفوع') {
                      statusColor = Colors.red;
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              item.paymentStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(item.invoicesCount.toString())),
                        DataCell(
                          Text(
                            "${item.totalAmount.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.paidAmount.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${item.remainingAmount.toStringAsFixed(2)} شيكل",
                            style: TextStyle(
                              color:
                                  item.remainingAmount > 0
                                      ? Colors.red
                                      : Colors.green,
                              fontWeight: FontWeight.bold,
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
