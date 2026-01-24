import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import 'package:pos_desktop/database/product_queries.dart';
import '../../widgets/product_category_filter.dart'; // Import reuse widget

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
  // New Callback for No Barcode Filter
  final Function(bool)? onNoBarcodeFilterChanged;
  final bool showNoBarcodeFilter;
  final GlobalKey<ProductCategoryFilterState>? categoryFilterKey;

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
    this.onNoBarcodeFilterChanged,
    this.showNoBarcodeFilter = false,
    this.categoryFilterKey,
  });

  @override
  State<ProductsTable> createState() => ProductsTableState();
}

class ProductsTableState extends State<ProductsTable> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  final Color _brandColor = const Color(0xFF4A80F0);

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchTerm;
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  void focusSearch() {
    FocusScope.of(context).requestFocus(_searchFocusNode);
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

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      // Allow spaces in search - don't trim here
      widget.onSearch?.call(value);
    });
  }

  void _handleSubmitted(String value) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (value.trim().isEmpty) return;

    final trimmedValue = value.trim();

    // محاولة البحث كباركود أولاً عند ضغط Enter
    final productByBarcode = await ProductQueries().getProductByBarcode(
      trimmedValue,
    );

    if (productByBarcode != null) {
      if (productByBarcode.id != null) {
        productByBarcode.packages = await ProductQueries()
            .getPackagesForProduct(productByBarcode.id!);
      }
      widget.onProductAdded(productByBarcode);

      _searchController.text = "";
      _searchController.clear();

      widget.onClearFilters?.call();
      FocusScope.of(context).requestFocus(_searchFocusNode);
    } else {
      widget.onSearch?.call(trimmedValue);
    }
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
        children: [
          // 1. الهيدر: بحث + تصنيفات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          onSubmitted: _handleSubmitted,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "بحث...",
                            prefixIcon: Icon(Icons.search, color: _brandColor),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code, size: 20),
                              focusNode: FocusNode(canRequestFocus: false),
                              onPressed: () {
                                _searchController.clear();
                                widget.onClearFilters?.call();
                                FocusScope.of(
                                  context,
                                ).requestFocus(_searchFocusNode);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _brandColor.withOpacity(0.1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _brandColor.withOpacity(0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _brandColor,
                                width: 1.5,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر فلتر بدون باركود
                    FilterChip(
                      label: const Text(
                        'بدون باركود',
                        style: TextStyle(fontSize: 11),
                      ),
                      selected: widget.showNoBarcodeFilter,
                      onSelected:
                          (val) => widget.onNoBarcodeFilterChanged?.call(val),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                      checkmarkColor: Colors.purple,
                      selectedColor: Colors.purple.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color:
                            widget.showNoBarcodeFilter
                                ? Colors.purple
                                : Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Unified Category Filter
                SizedBox(
                  height: 40, // Increased height for better interaction
                  child: ProductCategoryFilter(
                    key: widget.categoryFilterKey,
                    categories: widget.categories,
                    selectedCategoryId: widget.selectedCategoryId,
                    onCategorySelected:
                        (id) => widget.onCategorySelected?.call(id),
                  ),
                ),
              ],
            ),
          ),

          // 2. عناوين الجدول (Header Row)
          Focus(
            descendantsAreFocusable: false,
            skipTraversal: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      "المنتج",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "السعر",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40), // مساحة للزر
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 3. قائمة المنتجات
          Expanded(
            child: Focus(
              descendantsAreFocusable: false,
              skipTraversal: true,
              child:
                  widget.products.isEmpty
                      ? Center(
                        child: Text(
                          "لا توجد منتجات",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                      : ListView.separated(
                        controller: _scrollController,
                        itemCount:
                            widget.products.length + (widget.hasMore ? 1 : 0),
                        separatorBuilder:
                            (context, index) => const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                            ),
                        itemBuilder: (context, index) {
                          if (index == widget.products.length)
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          return _buildProductRow(widget.products[index]);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    bool hasStock = product.stock > 0;
    return InkWell(
      onTap: () => widget.onProductAdded(product),
      canRequestFocus: false, // تخطي سطر المنتج عند التنقل بالـ TAB
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // أيقونة المنتج
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  product.name.isNotEmpty ? product.name[0] : '?',
                  style: TextStyle(
                    color: _brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // اسم المنتج والمخزون
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "مخزون: ${product.stock.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 10,
                      color: hasStock ? Colors.grey : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            // السعر
            Expanded(
              child: Text(
                "${product.price.toStringAsFixed(1)} ₪",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // زر الإضافة
            IconButton(
              icon: Icon(Icons.add_circle, color: _brandColor),
              onPressed: () => widget.onProductAdded(product),
              focusNode: FocusNode(
                canRequestFocus: false,
              ), // تخطي زر الإضافة عند التنقل بالـ TAB
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
