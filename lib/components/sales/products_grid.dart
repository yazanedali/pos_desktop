import 'dart:async'; // 1. استيراد هذه المكتبة للمؤقت
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class ProductsGrid extends StatefulWidget {
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
  Timer? _debounce; // 2. متغير للمؤقت

  @override
  void initState() {
    super.initState();
    // ضبط النص الأولي فقط إذا كان مختلفاً
    if (widget.searchTerm != _searchController.text) {
      _searchController.text = widget.searchTerm;
    }
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(ProductsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تحديث النص فقط إذا تغير من المصدر الخارجي وليس أثناء الكتابة
    if (widget.searchTerm != oldWidget.searchTerm &&
        widget.searchTerm != _searchController.text) {
      // تأكد أن المؤشر لا يقفز
      final selection = _searchController.selection;
      _searchController.text = widget.searchTerm;
      // محاولة الحفاظ على موقع المؤشر إذا أمكن
      if (selection.baseOffset <= widget.searchTerm.length) {
        _searchController.selection = selection;
      }
    }
  }

  // 3. دالة معالجة تغيير النص مع التأخير (Debounce)
  void _onSearchChanged(String query) {
    // إلغاء المؤقت السابق إذا كان نشطاً (المستخدم لا يزال يكتب)
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // إنشاء مؤقت جديد ينتظر 500 ميلي ثانية قبل تنفيذ البحث
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (widget.onSearch != null) {
        widget.onSearch!(query);
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // تحميل قبل الوصول للنهاية بقليل
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 4. إلغاء المؤقت عند الخروج
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasFilters {
    return _searchController.text.isNotEmpty ||
        widget.selectedCategoryId != null;
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
                    onPressed: () {
                      _searchController.clear();
                      widget.onClearFilters?.call();
                    },
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
              onChanged: _onSearchChanged, // 5. استخدام دالة التأخير هنا
              onSubmitted: (val) {
                // البحث فوراً عند الضغط على Enter
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                widget.onSearch?.call(val);
              },
              decoration: InputDecoration(
                hintText: "ابحث بالاسم, الباركود, أو الفئة...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            // إلغاء المؤقت وتنفيذ بحث فارغ فوراً
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();
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

          // فلترة الفئات (نفس الكود السابق)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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

          // شبكة المنتجات (نفس الكود السابق)
          Expanded(
            child:
                widget.products.isEmpty
                    ? _buildEmptyState()
                    : NotificationListener<ScrollNotification>(
                      onNotification: (scrollNotification) {
                        // تم نقل المنطق إلى _setupScrollListener لكن هذا لا يضر
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

          if (widget.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // الدوال المساعدة (_buildEmptyState, _buildLoadMoreIndicator, _hexToColor) تبقى كما هي
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _hasFilters
                ? "لا توجد منتجات مطابقة للبحث"
                : "لا توجد منتجات متاحة",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
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
              width: 120, // عرض مضغوط
              height: 80, // ارتفاع مضغوط
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8), // زوايا أصغر
                border: Border.all(
                  color: _isHovering ? Colors.blue : Colors.grey.shade200,
                  width: _isHovering ? 1.5 : 1,
                ),
                boxShadow:
                    _isHovering
                        ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0), // padding أصغر
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // اسم المنتج
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // السعر والمخزون في سطر واحد
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.product.price.toStringAsFixed(0)} ش",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.product.stock > 0
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color:
                                  widget.product.stock > 0
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.red.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 10,
                                color:
                                    widget.product.stock > 0
                                        ? Colors.green
                                        : Colors.red,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                widget.product.stock.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.product.stock > 0
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // شارة الفئة - مصغرة
            Positioned(
              top: -6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
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
