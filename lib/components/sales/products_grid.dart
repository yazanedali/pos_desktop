import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class ProductsGrid extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final void Function(Product) onProductAdded;

  const ProductsGrid({
    super.key,
    required this.products,
    required this.categories,
    required this.onProductAdded,
  });

  @override
  State<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<ProductsGrid> {
  String _searchTerm = "";

  // --- === 1. تعديل منطق البحث ليشمل الباركود والفئة === ---
  List<Product> get _filteredProducts {
    if (_searchTerm.isEmpty) return widget.products;

    final lowerCaseSearchTerm = _searchTerm.toLowerCase();

    return widget.products.where((product) {
      // البحث في اسم المنتج
      final nameMatch = product.name.toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // البحث في الباركود (مع التحقق من أنه ليس null)
      final barcodeMatch = (product.barcode ?? '').toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // البحث في اسم الفئة
      final category = widget.categories.firstWhere(
        (cat) => cat.id == product.categoryId,
        orElse: () => Category(id: 0, name: '', color: ''), // fallback آمن
      );
      final categoryMatch = category.name.toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // إرجاع المنتج إذا تطابق أي من الشروط
      return nameMatch || barcodeMatch || categoryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // --- === 2. تعديل الواجهة لإضافة العنوان والبحث === ---
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          // ignore: deprecated_member_use
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- العنوان الجديد ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "المنتجات المتاحة (${_filteredProducts.length})",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2B4D),
              ),
            ),
          ),
          // --- مربع البحث الجديد ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchTerm = value),
              decoration: InputDecoration(
                hintText: "ابحث بالاسم, الباركود, أو الفئة...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // --- شبكة المنتجات (تبقى كما هي) ---
          Expanded(
            child:
                _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.9,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ProductSaleCard(
                          product: product,
                          category: widget.categories.firstWhere(
                            (cat) => cat.id == product.categoryId,
                            orElse:
                                () => Category(
                                  id: 0,
                                  name: 'غير مصنف',
                                  color: '#808080',
                                ),
                          ),
                          onTap: () => widget.onProductAdded(product),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "لا توجد منتجات مطابقة للبحث",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// --- بطاقة المنتج (ProductSaleCard) تبقى كما هي بدون أي تغيير ---
class ProductSaleCard extends StatefulWidget {
  final Product product;
  final Category category;
  final VoidCallback onTap;

  const ProductSaleCard({
    super.key,
    required this.product,
    required this.category,
    required this.onTap,
  });

  @override
  State<ProductSaleCard> createState() => _ProductSaleCardState();
}

class _ProductSaleCardState extends State<ProductSaleCard> {
  bool _isHovering = false;

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _hexToColor(widget.category.color);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovering ? Colors.blue : Colors.grey.shade200,
                  width: _isHovering ? 2 : 1,
                ),
                boxShadow:
                    _isHovering
                        ? [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ]
                        : [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(top: 12),
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.product.price.toStringAsFixed(2)} شيكل",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: categoryColor.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
