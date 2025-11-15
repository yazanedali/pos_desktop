import 'package:flutter/material.dart';
import '../components/product_management_page.dart';
import '../components/sales_interface.dart';
import '../components/sales_invoices.dart';
import '../components/purchase_invoices.dart';
import '../components/reports_section.dart';

class IndexPageWithDrawer extends StatefulWidget {
  const IndexPageWithDrawer({super.key});

  @override
  State<IndexPageWithDrawer> createState() => _IndexPageWithDrawerState();
}

class _IndexPageWithDrawerState extends State<IndexPageWithDrawer> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ProductManagementPage(),
    const SalesInterface(),
    const SalesInvoices(),
    const PurchaseInvoices(),
    const ReportsSection(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'إدارة المنتجات',
      'icon': Icons.inventory_2,
      'description': 'إضافة وتعديل وحذف المنتجات والفئات',
    },
    {
      'title': 'واجهة البيع',
      'icon': Icons.point_of_sale,
      'description': 'نقاط البيع وإدارة السلة',
    },
    {
      'title': 'فواتير المبيعات',
      'icon': Icons.receipt,
      'description': 'عرض وإدارة فواتير المبيعات',
    },
    {
      'title': 'فواتير الشراء',
      'icon': Icons.shopping_cart,
      'description': 'إدارة فواتير الشراء من الموردين',
    },
    {
      'title': 'التقارير والإحصائيات',
      'icon': Icons.analytics,
      'description': 'تقارير المبيعات والمشتريات والأرباح',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _menuItems[_currentIndex]['title'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _pages[_currentIndex],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            height: 150,
            width: double.infinity,
            color: Colors.blue[800],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'نظام إدارة المبيعات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color:
                        _currentIndex == index
                            ? Colors.blue[800]
                            : Colors.grey[600],
                  ),
                  title: Text(
                    item['title'],
                    style: TextStyle(
                      fontWeight:
                          _currentIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color:
                          _currentIndex == index
                              ? Colors.blue[800]
                              : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    item['description'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing:
                      _currentIndex == index
                          ? Icon(Icons.check, color: Colors.blue[800])
                          : null,
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Column(
              children: [
                Text(
                  'نظام نقاط البيع',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'الإصدار 1.0.0',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
