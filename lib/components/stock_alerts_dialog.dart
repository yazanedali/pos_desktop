import 'package:flutter/material.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/product.dart';

class StockAlertsDialog extends StatefulWidget {
  const StockAlertsDialog({super.key});

  @override
  State<StockAlertsDialog> createState() => _StockAlertsDialogState();
}

class _StockAlertsDialogState extends State<StockAlertsDialog> {
  final ProductQueries _productQueries = ProductQueries();
  List<Product> _lowStockProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productQueries.getLowStockProducts();
      if (mounted) {
        setState(() {
          _lowStockProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "تنبيهات المخزون",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _lowStockProducts.isEmpty
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green,
                            ),
                            SizedBox(height: 16),
                            Text("جميع الأصناف متوفرة بوفرة"),
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: _lowStockProducts.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final product = _lowStockProducts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  product.stock <= 0
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              child: Icon(
                                product.stock <= 0
                                    ? Icons.warning
                                    : Icons.history,
                                color:
                                    product.stock <= 0
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "الحد الأدنى: ${product.minStock.toInt()} | الباركود: ${product.barcode ?? '-'}",
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    product.stock <= 0
                                        ? Colors.red
                                        : Colors.orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${product.stock.toInt()}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
