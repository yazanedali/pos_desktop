import 'package:flutter/material.dart';
import 'package:pos_desktop/models/report_models_new.dart';
import 'package:intl/intl.dart' as intl; // تأكد من استيراد هذه المكتبة

class RealProfitCard extends StatelessWidget {
  final RealProfitStat data;

  const RealProfitCard({Key? key, required this.data}) : super(key: key);

  // دالة مساعدة لتنسيق العملة (فواصل + منزلتين + شيكل)
  String _formatMoney(double amount) {
    final formatter = intl.NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(amount)} شيكل';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'الربح الحقيقي (المحقق)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'بناءً على السيولة المحصلة فقط',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صافي الربح المحقق',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  // تعديل هنا: إضافة شيكل وتنسيق الرقم
                  Text(
                    _formatMoney(data.realizedProfit),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'الربح الدفتري (المتوقع)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  // تعديل هنا: إضافة شيكل وتنسيق الرقم
                  Text(
                    _formatMoney(data.grossProfit),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نسبة التحصيل: ${(data.collectionRatio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  // تعديل هنا: إضافة شيكل وتنسيق الرقم للمبيعات أيضاً
                  Text(
                    'المبيعات: ${_formatMoney(data.totalSales)}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: data.collectionRatio.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getColorForRatio(data.collectionRatio),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForRatio(double ratio) {
    if (ratio >= 0.9) return Colors.greenAccent;
    if (ratio >= 0.5) return Colors.amberAccent;
    return Colors.redAccent;
  }
}
