import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class ProductsGrid extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final void Function(Product) onProductAdded;

  // خصائص Lazy Loading الجديدة
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Function(String)? onSearch;
  final Function(int?)? onCategorySelected;
  final int? selectedCategoryId;
  final String searchTerm;
  final VoidCallback? onClearFilters;

  const ProductsGrid({
    super.key,
    required this.products,
    required this.categories,
    required this.onProductAdded,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.onSearch,
    this.onCategorySelected,
    this.selectedCategoryId,
    this.searchTerm = "",
    this.onClearFilters,
  });

  @override
  State<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<ProductsGrid> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchTerm;
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(ProductsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchTerm != widget.searchTerm) {
      _searchController.text = widget.searchTerm;
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasFilters {
    return widget.searchTerm.isNotEmpty || widget.selectedCategoryId != null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان وعدد المنتجات
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  "المنتجات المتاحة (${widget.products.length})",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4D),
                  ),
                ),
                const Spacer(),
                if (_hasFilters) ...[
                  Chip(
                    label: const Text('فلترة مفعلة'),
                    backgroundColor: Colors.orange[100],
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onClearFilters,
                    child: const Text('مسح الفلترة'),
                  ),
                ],
              ],
            ),
          ),

          // مربع البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                hintText: "ابحث بالاسم, الباركود, أو الفئة...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearch?.call("");
                          },
                        )
                        : null,
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

          // فلترة الفئات
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // زر عرض الكل
                  InkWell(
                    onTap: () => widget.onCategorySelected?.call(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            widget.selectedCategoryId == null
                                ? Colors.blue[100]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'الكل',
                        style: TextStyle(
                          color:
                              widget.selectedCategoryId == null
                                  ? Colors.blue[800]
                                  : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // قائمة الفئات
                  ...widget.categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap:
                            () => widget.onCategorySelected?.call(category.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.selectedCategoryId == category.id
                                    ? _hexToColor(category.color)
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color:
                                  widget.selectedCategoryId == category.id
                                      ? Colors.white
                                      : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          // شبكة المنتجات مع Lazy Loading
          Expanded(
            child:
                widget.products.isEmpty
                    ? _buildEmptyState()
                    : NotificationListener<ScrollNotification>(
                      onNotification: (scrollNotification) {
                        if (scrollNotification is ScrollEndNotification) {
                          if (_scrollController.position.pixels ==
                              _scrollController.position.maxScrollExtent) {
                            widget.onLoadMore?.call();
                          }
                        }
                        return false;
                      },
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount:
                            widget.products.length + (widget.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // مؤشر تحميل المزيد
                          if (index == widget.products.length &&
                              widget.hasMore) {
                            return _buildLoadMoreIndicator();
                          }

                          final product = widget.products[index];
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
          ),

          // مؤشر تحميل إضافي
          if (widget.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.searchTerm.isNotEmpty || widget.selectedCategoryId != null
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            widget.searchTerm.isNotEmpty || widget.selectedCategoryId != null
                ? "لا توجد منتجات مطابقة للبحث"
                : "لا توجد منتجات متاحة",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (widget.searchTerm.isNotEmpty ||
              widget.selectedCategoryId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: widget.onClearFilters,
              child: const Text('مسح الفلترة'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return GestureDetector(
      onTap: widget.onLoadMore,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'تحميل المزيد',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }
}

// ProductSaleCard يبقى كما هو بدون تغيير
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
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ]
                        : [
                          BoxShadow(
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
