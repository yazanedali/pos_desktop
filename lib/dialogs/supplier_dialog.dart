import 'package:flutter/material.dart';
import 'package:pos_desktop/database/supplier_queries.dart';
import 'package:pos_desktop/models/supplier.dart';

class SupplierDialog extends StatefulWidget {
  final Supplier? supplier;
  const SupplierDialog({super.key, this.supplier});

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _openingBalanceNotesController = TextEditingController();
  final SupplierQueries _supplierQueries = SupplierQueries();

  String _paymentType = 'نقدي';
  final List<String> _paymentTypes = ['نقدي', 'تحويل بنكي', 'شيك'];

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _phoneController.text = widget.supplier!.phone ?? '';
      _addressController.text = widget.supplier!.address ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? "إضافة مورد" : "تعديل مورد"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم المورد *"),
                validator: (value) => value!.isEmpty ? "الاسم مطلوب" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "رقم الهاتف"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: "العنوان"),
                maxLines: 2,
              ),

              // قسم الرصيد الافتتاحي (فقط عند الإضافة)
              if (widget.supplier == null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  "الرصيد الافتتاحي",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _openingBalanceController,
                  decoration: const InputDecoration(
                    labelText: "المبلغ",
                    hintText: "0.0",
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _openingBalanceNotesController,
                  decoration: const InputDecoration(
                    labelText: "ملاحظات الرصيد الافتتاحي",
                    hintText: "مثال: رصيد سابق، دفعة مقدمة، إلخ",
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentType,
                  decoration: const InputDecoration(labelText: "طريقة الدفع"),
                  items:
                      _paymentTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _paymentType = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  "ملاحظة: الرصيد الافتتاحي يمثل المبلغ الذي تدين به للمورد عند بداية التعامل",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                final supplier = Supplier(
                  id: widget.supplier?.id,
                  name: _nameController.text,
                  phone: _phoneController.text,
                  address: _addressController.text,
                );

                if (widget.supplier == null) {
                  // إضافة جديد مع الرصيد الافتتاحي
                  double openingBalance =
                      double.tryParse(_openingBalanceController.text) ?? 0.0;

                  await _supplierQueries.insertSupplierWithOpeningBalance(
                    supplier,
                    openingBalance,
                    _paymentType,
                    _openingBalanceNotesController.text,
                  );
                } else {
                  // تعديل فقط (لا يمكن تعديل الرصيد الافتتاحي)
                  await _supplierQueries.updateSupplier(supplier);
                }

                if (mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: const Text("حفظ"),
        ),
      ],
    );
  }
}
