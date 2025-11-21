// dialogs/customer_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/debtor_info.dart';

class CustomerDialog extends StatelessWidget {
  final Customer customer;
  final DebtorInfo debtorInfo;
  final VoidCallback onEdit;

  const CustomerDialog({
    super.key,
    required this.customer,
    required this.debtorInfo,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: const [
          Icon(Icons.person_outline),
          SizedBox(width: 8),
          Text("تفاصيل العميل"),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.35,
        child: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              _buildDetailRow(
                Icons.badge_outlined,
                'الاسم:',
                customer.name,
                isTitle: true,
              ),
              _buildDetailRow(
                Icons.phone_outlined,
                'الهاتف:',
                customer.phone ?? 'لا يوجد',
              ),
              _buildDetailRow(
                Icons.location_on_outlined,
                'العنوان:',
                customer.address ?? 'لا يوجد',
              ),
              const Divider(height: 24),
              _buildDetailRow(
                Icons.account_balance_wallet_outlined,
                'إجمالي الدين الحالي:', //   <-- تم تغيير النص للتوضيح
                '${debtorInfo.totalDebt.toStringAsFixed(2)} شيكل',
                color:
                    debtorInfo.totalDebt > 0
                        ? Colors.red.shade700
                        : Colors.green,
                isTitle: true, //   <-- تم تكبير الخط لتمييزه
              ),

              //   ***** تم حذف الأسطر التي تسببت في الخطأ من هنا *****
              // _buildDetailRow('دين افتتاحي', ...),
              // _buildDetailRow('ملاحظات', ...),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  // ودجت مساعد لعرض كل صف من التفاصيل
  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isTitle = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100, // عرض ثابت للعنوان
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTitle ? 16 : 14,
                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
