import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories;
  final Function(Product) onEdit;
  final Function(int) onDelete;

  const ProductGrid({
    super.key,
    required this.products,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // --- === هذا هو الحل السحري للتجاوب وحجم الكروت === ---
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 3 / 2.2, // ← قلّل الارتفاع
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),

      // --- ================================================= ---
      itemCount: products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          categories: categories,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}
