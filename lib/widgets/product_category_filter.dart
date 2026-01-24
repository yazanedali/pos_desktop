import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/category.dart';

class ProductCategoryFilter extends StatefulWidget {
  final List<Category> categories;
  final int? selectedCategoryId;
  final Function(int?) onCategorySelected;

  const ProductCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  State<ProductCategoryFilter> createState() => ProductCategoryFilterState();
}

class ProductCategoryFilterState extends State<ProductCategoryFilter> {
  final FocusNode focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Handle number keys (1-9) for direct category selection
    if (event.logicalKey.keyId >= LogicalKeyboardKey.digit1.keyId &&
        event.logicalKey.keyId <= LogicalKeyboardKey.digit9.keyId) {
      final index = event.logicalKey.keyId - LogicalKeyboardKey.digit1.keyId;
      if (index == 0) {
        // 1 = الكل (All)
        widget.onCategorySelected(null);
      } else if (index - 1 < widget.categories.length) {
        // 2-9 = categories
        widget.onCategorySelected(widget.categories[index - 1].id);
      }
      return;
    }

    // Handle arrow keys for navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _navigatePrevious();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _navigateNext();
    }
  }

  void _navigateNext() {
    if (widget.selectedCategoryId == null) {
      // Currently on "All", move to first category
      if (widget.categories.isNotEmpty) {
        widget.onCategorySelected(widget.categories[0].id);
      }
    } else {
      // Find current category index
      final currentIndex = widget.categories.indexWhere(
        (cat) => cat.id == widget.selectedCategoryId,
      );
      if (currentIndex != -1 && currentIndex < widget.categories.length - 1) {
        // Move to next category
        widget.onCategorySelected(widget.categories[currentIndex + 1].id);
      }
    }
  }

  void _navigatePrevious() {
    if (widget.selectedCategoryId == null) {
      // Already on "All", do nothing
      return;
    } else {
      // Find current category index
      final currentIndex = widget.categories.indexWhere(
        (cat) => cat.id == widget.selectedCategoryId,
      );
      if (currentIndex > 0) {
        // Move to previous category
        widget.onCategorySelected(widget.categories[currentIndex - 1].id);
      } else if (currentIndex == 0) {
        // Move to "All"
        widget.onCategorySelected(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => focusNode.requestFocus(),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, // Always show scrollbar
          thickness: 8.0,
          radius: const Radius.circular(4),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // زر عرض الكل
                _buildCategoryChip(
                  label: 'الكل (1)',
                  isSelected: widget.selectedCategoryId == null,
                  color: Colors.blue,
                  onTap: () => widget.onCategorySelected(null),
                ),
                const SizedBox(width: 8),

                // قائمة الفئات
                ...widget.categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final isSelected = widget.selectedCategoryId == category.id;
                  final numberLabel = index < 8 ? ' (${index + 2})' : '';

                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildCategoryChip(
                      label: '${category.name}$numberLabel',
                      isSelected: isSelected,
                      color: _hexToColor(category.color),
                      onTap: () => widget.onCategorySelected(category.id),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
