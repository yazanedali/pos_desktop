import 'package:flutter/material.dart';
import '../../models/report_models.dart';

class ActualProfitsReport extends StatelessWidget {
  final List<ActualProfitReportData> data;

  const ActualProfitsReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // حساب الإجماليات
    final totalSales = data.fold(0.0, (sum, item) => sum + item.sales);
    final totalCostOfGoodsSold = data.fold(
      0.0,
      (sum, item) => sum + item.costOfGoodsSold,
    );
    final totalActualProfit = data.fold(
      0.0,
      (sum, item) => sum + item.actualProfit,
    );
    final avgProfitMargin =
        totalSales > 0 ? (totalActualProfit / totalSales) * 100 : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green[800]),
                const SizedBox(width: 8),
                const Text(
                  "تقرير الربح الفعلي",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // بطاقة ملخص الأرباح
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'إجمالي المبيعات:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${totalSales.toStringAsFixed(2)} شيكل',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تكلفة البضاعة المباعة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${totalCostOfGoodsSold.toStringAsFixed(2)} شيكل',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الربح الفعلي:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${totalActualProfit.toStringAsFixed(2)} شيكل',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                totalActualProfit >= 0
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'متوسط هامش الربح:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${avgProfitMargin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color:
                                avgProfitMargin >= 0
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // جدول التفاصيل
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text("التاريخ")),
                  DataColumn(label: Text("المبيعات")),
                  DataColumn(label: Text("التكلفة")),
                  DataColumn(label: Text("الربح الفعلي")),
                  DataColumn(label: Text("هامش الربح %")),
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
                              "${item.costOfGoodsSold.toStringAsFixed(2)} شيكل",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          DataCell(
                            Text(
                              "${item.actualProfit.toStringAsFixed(2)} شيكل",
                              style: TextStyle(
                                color:
                                    item.actualProfit >= 0
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              "${item.profitMargin.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color:
                                    item.profitMargin >= 0
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
