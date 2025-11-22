import 'package:flutter/material.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';
import '../../models/sales_invoice.dart';

class InvoiceCard extends StatelessWidget {
  final SaleInvoice invoice;
  final VoidCallback onTap;
  final String customerName;
  final bool showReturnButton;
  final VoidCallback? onReturn;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.customerName,
    this.showReturnButton = true,
    this.onReturn,
  });

  void _showReturnConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl, // 🍀 هنا التحويل لليمين
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('تأكيد إرجاع الفاتورة'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رقم الفاتورة: ${invoice.invoiceNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'هل أنت متأكد من أنك تريد إرجاع هذه الفاتورة؟',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('• إرجاع جميع المنتجات إلى المخزون'),
                  const Text('• حذف الفاتورة نهائياً من النظام'),
                  if (invoice.remainingAmount > 0)
                    const Text('• إرجاع المبالغ المدفوعة والمديونية'),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ لا يمكن التراجع عن هذه العملية',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actionsAlignment:
                  MainAxisAlignment.start, // يجعل الأزرار من اليمين
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => _returnInvoice(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('نعم، إرجاع الفاتورة'),
                ),
              ],
            ),
          ),
    );
  }

  void _returnInvoice(BuildContext context) async {
    try {
      Navigator.pop(context); // إغلاق ديالوج التأكيد

      // عرض مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // استدعاء خدمة الإرجاع
      final success = await SalesInvoiceService().returnInvoice(invoice.id!);

      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        // إظهار رسالة نجاح
        if (context.mounted) {
          TopAlert.showSuccess(
            context: context,
            message: "تم إرجاع الفاتورة ${invoice.invoiceNumber} بنجاح.",
          );

          // تحديث القائمة
          if (onReturn != null) {
            onReturn!();
          }
        }
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل في حالة الخطأ

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرجاع الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _getStatusColor(invoice.paymentStatus)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الصف الأول: رقم الفاتورة ونوع الدفع
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[300]!),
                          ),
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(invoice.paymentType),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.paymentType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(invoice.paymentStatus),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.paymentStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (showReturnButton)
                          IconButton(
                            onPressed: () => _showReturnConfirmation(context),
                            icon: const Icon(Icons.reply, color: Colors.red),
                            tooltip: 'إرجاع الفاتورة',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الصف الثاني: عدد المنتجات
                    Text(
                      "${invoice.items.length} منتج",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),

                    // الصف الثالث: التاريخ والكاشير
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${invoice.date} - ${invoice.time}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          invoice.cashier,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          customerName,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // الصف الرابع: المبلغ المتبقي (إذا كان هناك دين)
                    if (invoice.remainingAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 12,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "متبقي: ${invoice.remainingAmount.toStringAsFixed(2)} شيكل",
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${invoice.total.toStringAsFixed(2)} شيكل",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "مدفوع: ${invoice.paidAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          invoice.paidAmount == invoice.total
                              ? Colors.green
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      "عرض التفاصيل",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة للحصول على لون حالة السداد
  Color _getStatusColor(String status) {
    switch (status) {
      case 'مدفوع':
        return Colors.green;
      case 'جزئي':
        return Colors.orange;
      case 'غير مدفوع':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // دالة للحصول على لون نوع الدفع
  Color _getTypeColor(String type) {
    switch (type) {
      case 'نقدي':
        return Colors.green;
      case 'آجل':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
