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
  final SupplierQueries _supplierQueries = SupplierQueries();

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
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "اسم المورد *"),
              validator: (value) =>
                  value!.isEmpty ? "الاسم مطلوب" : null,
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: "العنوان"),
            ),
          ],
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
              final supplier = Supplier(
                id: widget.supplier?.id,
                name: _nameController.text,
                phone: _phoneController.text,
                address: _addressController.text,
              );

              if (widget.supplier == null) {
                await _supplierQueries.insertSupplier(supplier);
              } else {
                await _supplierQueries.updateSupplier(supplier);
              }

              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text("حفظ"),
        ),
      ],
    );
  }
}
