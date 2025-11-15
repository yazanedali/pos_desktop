import 'package:flutter/material.dart';
import '../components/product_management_page.dart';
import '../components/sales_interface.dart';
import '../components/sales_invoices.dart';
import '../components/purchase_invoices.dart';
import '../components/reports_section.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const ProductManagementPage(),
    const SalesInterface(),
    const SalesInvoices(),
    const PurchaseInvoices(),
    const ReportsSection(),
  ];

  final List<String> _pageTitles = [
    'المنتجات',
    'نقطة البيع',
    'فواتير المبيعات',
    'فواتير الشراء',
    'التقارير',
  ];

  final List<IconData> _pageIcons = [
    Icons.inventory_2_outlined,
    Icons.shopping_cart_checkout,
    Icons.receipt_long_outlined,
    Icons.shopping_bag_outlined,
    Icons.analytics_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. الشريط العلوي الجديد (Header) ---
            _buildHeader(),
            // --- 2. شريط التنقل الذي قمنا بعمله سابقًا ---
            _buildCustomNavigationBar(),
            // --- 3. عرض الصفحة المحددة ---
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

  // --- === دالة جديدة لبناء الشريط العلوي (Header) === ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // --- الجزء الأيسر: حالة المتجر ---
          Row(
            children: [
              _buildStatusChip("متصل", Colors.green[100]!, Colors.green[800]!),
              const SizedBox(width: 12),
              _buildStatusChip(
                "المتجر الرئيسي",
                Colors.grey[200]!,
                Colors.grey[800]!,
              ),
            ],
          ),
          // --- الجزء الأيمن: شعار واسم النظام ---
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "نظام نقطة البيع",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2B4D),
                    ),
                  ),
                  Text(
                    "إدارة ذكية للمبيعات والمخزون",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- دالة مساعدة لبناء الـ Chips في الهيدر ---
  Widget _buildStatusChip(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // --- دالة شريط التنقل (لا تغيير هنا) ---
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
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_pages.length, (index) {
          return Expanded(child: _buildNavItem(index));
        }),
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
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration:
                  isSelected
                      ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                      : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // -------- المؤشر (Indicator) --------
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
    );
  }
}
