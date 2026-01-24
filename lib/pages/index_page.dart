import 'package:flutter/material.dart';
import 'package:pos_desktop/components/multi_tab_sales_page.dart';
import '../components/product_management_page.dart';
import '../components/sales_invoices.dart';
import '../components/purchase_invoices.dart';
import '../components/reports/new_reports_page.dart';
import '../components/customers_and_suppliers_page.dart';
import '../components/cash_management_page.dart';
import '../components/stock_alerts_dialog.dart';
import '../services/stock_alert_service.dart';
import 'shift_closing_page.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;
  bool _isNavBarCollapsed = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Initial check
    StockAlertService().checkAlerts();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleNavBar() {
    setState(() {
      _isNavBarCollapsed = !_isNavBarCollapsed;
      if (_isNavBarCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showStockAlerts() {
    showDialog(
      context: context,
      builder: (context) => const StockAlertsDialog(),
    ).then((_) => StockAlertService().checkAlerts());
  }

  final List<Widget> _pages = [
    const ProductManagementPage(),
    const MultiTabSalesPage(),
    const SalesInvoices(),
    const PurchaseInvoices(),
    const NewReportsPage(),
    const CustomersAndSuppliersPage(),
    const CashManagementPage(),
    const ShiftClosingPage(),
  ];

  final List<String> _pageTitles = [
    'المنتجات',
    'نقطة البيع',
    'فواتير المبيعات',
    'فواتير الشراء',
    'التقارير',
    'العملاء والموردين',
    'الصندوق',
    'إغلاق الوردية',
  ];

  final List<IconData> _pageIcons = [
    Icons.inventory_2_outlined,
    Icons.shopping_cart_checkout,
    Icons.receipt_long_outlined,
    Icons.shopping_bag_outlined,
    Icons.analytics_outlined,
    Icons.people_alt_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.access_time_filled_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: _isNavBarCollapsed ? 50 : null,
              child: Stack(
                children: [
                  _buildCompactNavigationBar(),
                  _buildFloatingControls(),
                ],
              ),
            ),
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

  Widget _buildCompactNavigationBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, 12, 16, _isNavBarCollapsed ? 4 : 12),
      height: _isNavBarCollapsed ? 0 : 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Navigation items (take most space)
                  Expanded(
                    child: Row(
                      children: List.generate(_pages.length, (index) {
                        return Expanded(child: _buildCompactNavItem(index));
                      }),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 32,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.grey[200],
                  ),

                  // Notification bell
                  _buildInlineNotificationBell(),

                  const SizedBox(width: 4),

                  // Toggle button
                  _buildInlineToggleButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavItem(int index) {
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
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            gradient:
                isSelected
                    ? const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: const Color(0xFF4A80F0).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _pageIcons[index],
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _pageTitles[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleNavBar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedRotation(
            turns: _isNavBarCollapsed ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.grey[700],
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineNotificationBell() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showStockAlerts,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_outlined,
                color: Colors.grey[700],
                size: 22,
              ),
              Positioned(
                right: -4,
                top: -4,
                child: ValueListenableBuilder<int>(
                  valueListenable: StockAlertService().alertCountNotifier,
                  builder: (context, count, child) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep floating versions for when navbar is collapsed
  Widget _buildFloatingControls() {
    if (!_isNavBarCollapsed) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      right: 16,
      child: Row(
        children: [
          _buildFloatingNotificationBell(),
          const SizedBox(width: 8),
          _buildFloatingToggleButton(),
        ],
      ),
    );
  }

  Widget _buildFloatingNotificationBell() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showStockAlerts,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(_isNavBarCollapsed ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey[700],
                  size: _isNavBarCollapsed ? 20 : 22,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: ValueListenableBuilder<int>(
                    valueListenable: StockAlertService().alertCountNotifier,
                    builder: (context, count, child) {
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: EdgeInsets.all(_isNavBarCollapsed ? 3 : 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: _isNavBarCollapsed ? 14 : 16,
                          minHeight: _isNavBarCollapsed ? 14 : 16,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _isNavBarCollapsed ? 8 : 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleNavBar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: _isNavBarCollapsed ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.grey[700],
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
