import 'package:flutter/material.dart';
import '../../models/product.dart';
import '/widgets/top_alert.dart';

class BarcodeReader extends StatefulWidget {
  // 2. تم تحديد نوع الدالة بشكل أدق
  final void Function(Product) onProductScanned;
  final List<Product> products;

  const BarcodeReader({
    super.key,
    required this.onProductScanned,
    required this.products,
  });

  @override
  State<BarcodeReader> createState() => _BarcodeReaderState();
}

class _BarcodeReaderState extends State<BarcodeReader> {
  final _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(); // ← إضافة FocusNode

  @override
  void initState() {
    super.initState();
    // نجعل التركيز دائم عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_barcodeFocusNode);
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose(); // ← مسح FocusNode
    super.dispose();
  }

  void _handleBarcodeSubmit() {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final product = widget.products.firstWhere(
      (p) => p.barcode == barcode,
      orElse: () => Product(id: null, name: '', price: 0, stock: 0),
    );

    if (product.id != null) {
      widget.onProductScanned(product);
      _barcodeController.clear();
      // بعد مسح النص نعيد التركيز تلقائيًا
      FocusScope.of(context).requestFocus(_barcodeFocusNode);
    } else {
      TopAlert.showError(
        context: context,
        message: 'لم يتم العثور على منتج بهذا الباركود',
      );
      _barcodeController.clear();
      FocusScope.of(context).requestFocus(_barcodeFocusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.blue[800]),
              const SizedBox(width: 8),
              const Text(
                "قارئ الباركود",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode, // ← ربط الـ FocusNode
                  decoration: const InputDecoration(
                    hintText: "امسح الباركود أو اكتبه...",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  onSubmitted: (_) => _handleBarcodeSubmit(),
                  autofocus: true, // ← لضمان فتح المؤشر تلقائيًا
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _handleBarcodeSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text("إضافة"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
