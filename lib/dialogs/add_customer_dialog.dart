// dialogs/add_customer_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//   ***** تم حذف استيرادات DebtorInfo و Customer لأنها لم تعد مطلوبة هنا *****

class AddCustomerDialog extends StatefulWidget {
  //   ***** تم حذف كل ما يتعلق بـ customerToEdit و debtorInfo *****
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();

  //   ***** تم جعل الـ Controllers نهائية (final) *****
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController();
  final _notesController = TextEditingController();

  //   ***** تم حذف متغير _isEditing و initState بالكامل *****

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  //   ***** 3. تبسيط دالة الحفظ *****
  void _onSave() {
    if (_formKey.currentState!.validate()) {
      // الواجهة الآن تعيد دائمًا خريطة بيانات للإضافة فقط
      final result = {
        'name': _nameController.text.trim(),
        'phone':
            _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
        'address':
            _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
        'opening_balance': double.tryParse(_balanceController.text) ?? 0.0,
        'notes':
            _notesController.text.trim().isNotEmpty
                ? "رصيد افتتاحي: ${_notesController.text.trim()}"
                : "رصيد افتتاحي سابق",
      };
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      //   ***** 4. عنوان ثابت *****
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Colors.blue[800]),
          const SizedBox(width: 8),
          const Text('إضافة عميل جديد'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'اسم العميل مطلوب'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                //   ***** 5. تم تبسيط الحقول لتظهر دائمًا *****
                TextFormField(
                  controller: _balanceController,
                  decoration: const InputDecoration(
                    labelText: 'رصيد دين سابق (إن وجد)',
                    hintText: '0.0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    suffixText: 'شيكل',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _onSave,
          icon: const Icon(Icons.save, size: 18),
          //   ***** 6. نص زر ثابت *****
          label: const Text('حفظ العميل'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
