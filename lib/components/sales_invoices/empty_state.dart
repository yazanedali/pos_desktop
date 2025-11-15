import 'package:flutter/material.dart';

class EmptyInvoicesState extends StatelessWidget {
  const EmptyInvoicesState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "لا توجد فواتير مبيعات حتى الآن",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "ستظهر الفواتير هنا بعد إتمام عمليات البيع",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
