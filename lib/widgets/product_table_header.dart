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
          // الرقم التسلسلي (عنوان مخفي)
          SizedBox(width: 56),

          Expanded(
            flex: 2,
            child: Text(
              'المنتج',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(width: 16),

          Expanded(
            flex: 1,
            child: Text(
              'الكمية',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(width: 16),

          Expanded(
            flex: 1,
            child: Text(
              'سعر الشراء',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(width: 16),

          Expanded(
            flex: 1,
            child: Text(
              'سعر البيع',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(width: 16),

          Expanded(
            flex: 1,
            child: Text(
              'الفئة',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SizedBox(
            width: 100,
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
