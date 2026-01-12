import 'package:flutter/material.dart';
import 'package:pos_desktop/components/multi_tab_sales_page.dart';
import 'package:pos_desktop/database/backup_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';
import '../components/product_management_page.dart';
import '../components/sales_invoices.dart';
import '../components/purchase_invoices.dart';
import '../components/reports/new_reports_page.dart';
import '../components/customers_and_suppliers_page.dart';
import '../components/cash_management_page.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const ProductManagementPage(),
    const MultiTabSalesPage(),
    const SalesInvoices(),
    const PurchaseInvoices(),
    const NewReportsPage(),
    const CustomersAndSuppliersPage(),
    const CashManagementPage(),
  ];

  final List<String> _pageTitles = [
    'المنتجات',
    'نقطة البيع',
    'فواتير المبيعات',
    'فواتير الشراء',
    'التقارير',
    'العملاء والموردين',
    'الصندوق',
  ];

  final List<IconData> _pageIcons = [
    Icons.inventory_2_outlined,
    Icons.shopping_cart_checkout,
    Icons.receipt_long_outlined,
    Icons.shopping_bag_outlined,
    Icons.analytics_outlined,
    Icons.people_alt_outlined,
    Icons.account_balance_wallet_outlined,
  ];

  // 2. دالة تنفيذ النسخ الاحتياطي
  // 2. دالة تنفيذ النسخ الاحتياطي باستخدام TopAlert
  Future<void> _performBackup() async {
    // إظهار دائرة تحميل (يمكنك أيضاً استبدالها بـ TopAlert إذا أردت)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final backupService = BackupService();
    String result = await backupService.createBackup(isAuto: false);

    if (!mounted) return;

    // إغلاق دائرة التحميل
    Navigator.pop(context);

    // التحقق من النتيجة لعرض التنبيه المناسب
    if (result.contains("نجاح")) {
      TopAlert.showSuccess(context: context, message: result);
    } else if (result.contains("فقط")) {
      // حالة النجاح الجزئي (محلياً فقط)
      TopAlert.showWarning(context: context, message: result);
    } else {
      // حالة الفشل الكامل
      TopAlert.showError(context: context, message: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            // _buildHeader(), // الهيدر القديم معطل كما طلبت
            _buildCustomNavigationBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. تعديل شريط التنقل لإضافة زر النسخ الاحتياطي
  Widget _buildCustomNavigationBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // قائمة الصفحات (تأخذ المساحة المتبقية)
          ...List.generate(_pages.length, (index) {
            return Expanded(child: _buildNavItem(index));
          }),

          // فاصل عمودي صغير
          Container(
            height: 30,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // زر النسخ الاحتياطي (مميز بلون مختلف)
          _buildBackupButton(),
        ],
      ),
    );
  }

  // تصميم زر النسخ الاحتياطي
  Widget _buildBackupButton() {
    return Tooltip(
      message: 'نسخ احتياطي لقاعدة البيانات',
      textStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _performBackup,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              // لون برتقالي فاتح لتمييزه عن باقي الأزرار
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.backup_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "نسخ احتياطي",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal', // تأكيد الخط
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final bool isSelected = _selectedIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            gradient:
                isSelected
                    ? const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                    : null,
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _pageIcons[index],
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _pageTitles[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // قمت بتصغير الخط قليلاً ليتسع للجميع
                    ),
                  ),
                ],
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 6),
                height: 4,
                width: isSelected ? 28 : 0,
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF4A80F0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
