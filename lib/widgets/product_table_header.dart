import 'package:flutter/material.dart';

class ProductTableHeader extends StatelessWidget {
  const ProductTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[100]!)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'المنتج',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'الباركود',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'السعر',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'الفئة',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'إجراءات',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
