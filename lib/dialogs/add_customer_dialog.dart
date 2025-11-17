import 'package:flutter/material.dart';
import '../models/customer.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // دالة الحفظ عند الضغط على الزر
  void _onSave() {
    // التحقق من صحة الحقول
    if (_formKey.currentState!.validate()) {
      // إنشاء كائن عميل جديد بالبيانات المدخلة
      final newCustomer = Customer(
        name: _nameController.text.trim(),
        phone:
            _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
        address:
            _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
      );
      // إغلاق النافذة وإعادة كائن العميل الجديد للصفحة السابقة
      Navigator.of(context).pop(newCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // جعل الحواف دائرية لتتناسق مع التصميم
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Colors.blue[800]),
          const SizedBox(width: 8),
          const Text('إضافة عميل جديد'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- حقل اسم العميل ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  hintText: 'أدخل الاسم الكامل للعميل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم العميل مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- حقل رقم الهاتف ---
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  hintText: 'أدخل رقم هاتف العميل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // --- حقل العنوان ---
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  hintText: 'أدخل عنوان العميل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // زر الإلغاء
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        // زر الحفظ
        ElevatedButton.icon(
          onPressed: _onSave,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('حفظ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
