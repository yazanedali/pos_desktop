import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class ProductsTable extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final void Function(Product) onProductAdded;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Function(String)? onSearch;
  final Function(int?)? onCategorySelected;
  final int? selectedCategoryId;
  final String searchTerm;
  final VoidCallback? onClearFilters;

  const ProductsTable({
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
  State<ProductsTable> createState() => _ProductsTableState();
}

class _ProductsTableState extends State<ProductsTable> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchTerm;
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(ProductsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchTerm != oldWidget.searchTerm) {
      if (widget.searchTerm != _searchController.text) {
        _searchController.text = widget.searchTerm;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.onSearch?.call(query);
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFilters =
        _searchController.text.isNotEmpty || widget.selectedCategoryId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Count
                Row(
                  children: [
                    const Spacer(),
                    if (hasFilters)
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          widget.onClearFilters?.call();
                        },
                        icon: const Icon(Icons.filter_list_off, size: 18),
                        label: const Text('إلغاء الفلترة'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "بحث باسم المنتج أو الباركود...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Categories List (Improved UI)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildCategoryChip(
                          label: 'الكل',
                          isSelected: widget.selectedCategoryId == null,
                          onTap: () => widget.onCategorySelected?.call(null),
                        );
                      }
                      final category = widget.categories[index - 1];
                      return _buildCategoryChip(
                        label: category.name,
                        color: category.color,
                        isSelected: widget.selectedCategoryId == category.id,
                        onTap:
                            () => widget.onCategorySelected?.call(category.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child:
                widget.products.isEmpty
                    ? _buildEmptyState(hasFilters)
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 80),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          widget.products.length + (widget.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == widget.products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _buildProductRow(widget.products[index], index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    String? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final themeColor =
        color != null ? _hexToColor(color) : Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey[300]!,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(Product product, int index) {
    // استخدام try-catch أو orElse لتجنب خطأ Bad State
    Category category;
    try {
      category = widget.categories.firstWhere(
        (c) => c.id == product.categoryId,
        orElse: () => Category(id: 0, name: 'غير مصنف', color: '#9E9E9E'),
      );
    } catch (_) {
      category = Category(id: 0, name: 'غير مصنف', color: '#9E9E9E');
    }

    final categoryColor = _hexToColor(category.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: () => widget.onProductAdded(product),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: categoryColor.withOpacity(0.1),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
            style: TextStyle(color: categoryColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (product.barcode != null && product.barcode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.barcode!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: TextStyle(fontSize: 11, color: categoryColor),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'المخزون: ${product.stock.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: product.stock <= 0 ? Colors.red : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: () => widget.onProductAdded(product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasFilters) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.layers_clear,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? "لا توجد نتائج تطابق بحثك"
                : "لا توجد منتجات في هذه الفئة",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (hasFilters)
            TextButton(
              onPressed: () {
                _searchController.clear();
                widget.onClearFilters?.call();
              },
              child: const Text('عرض كل المنتجات'),
            ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll("#", "");
      if (hex.length == 6) hex = "FF$hex";
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey; // لون احتياطي في حال كان الكود اللوني خطأ
    }
  }
}
