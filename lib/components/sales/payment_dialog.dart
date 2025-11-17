// components/payment_dialog.dart

import 'package:flutter/material.dart';
import 'package:pos_desktop/database/customer_queries.dart';
import 'package:pos_desktop/dialogs/add_customer_dialog.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final List<Customer> customers;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.customers,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  // --- متغيرات الحالة ---
  final _formKey = GlobalKey<FormState>();
  final _paidAmountController = TextEditingController();
  final CustomerQueries _customerQueries = CustomerQueries();

  String _paymentMethod = 'نقدي';
  Customer? _selectedCustomer;
  late List<Customer> _availableCustomers;
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  final MenuController _menuController = MenuController(); // إضافة controller

  @override
  void initState() {
    super.initState();
    _paidAmountController.text = widget.totalAmount.toStringAsFixed(2);
    _availableCustomers = List.from(widget.customers);
    _searchResults = _availableCustomers;

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _searchResults = _availableCustomers;
      } else {
        _searchResults =
            _availableCustomers.where((customer) {
              return customer.name.toLowerCase().contains(query) ||
                  (customer.phone ?? '').toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  Future<void> _showAndHandleAddCustomer() async {
    final newCustomerFromDialog = await showDialog<Customer>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (newCustomerFromDialog != null && mounted) {
      try {
        final newId = await _customerQueries.insertCustomer(
          newCustomerFromDialog,
        );

        final newCompleteCustomer = Customer(
          id: newId,
          name: newCustomerFromDialog.name,
          phone: newCustomerFromDialog.phone,
          address: newCustomerFromDialog.address,
        );

        setState(() {
          _availableCustomers.add(newCompleteCustomer);
          _searchResults = _availableCustomers;
          _selectedCustomer = newCompleteCustomer;
          _searchController.clear();
        });

        TopAlert.showSuccess(
          context: context,
          message: 'تمت إضافة العميل واختياره',
        );
      } catch (e) {
        TopAlert.showError(
          context: context,
          message: 'فشل في إضافة العميل: $e',
        );
      }
    }
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      final double paidAmount =
          double.tryParse(_paidAmountController.text) ?? 0.0;
      final result = {
        'payment_method': _paymentMethod,
        'paid_amount': paidAmount,
        'customer_id': _selectedCustomer?.id,
      };
      Navigator.of(context).pop(result);
    }
  }

  // دالة لبناء القائمة المنسدلة مع البحث
  Widget _buildSearchableDropdown() {
    return MenuAnchor(
      controller: _menuController, // استخدام الـ controller
      builder: (context, controller, child) {
        return TextFormField(
          readOnly: true,
          controller: TextEditingController(
            text: _selectedCustomer?.name ?? '',
          ),
          decoration: InputDecoration(
            labelText: 'اختر العميل',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                        _searchController.clear();
                      });
                    },
                  ),
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          ),
          onTap: () {
            if (_menuController.isOpen) {
              _menuController.close();
            } else {
              _menuController.open();
              // إعطاء التركيز لحقل البحث عند فتح القائمة
              Future.delayed(const Duration(milliseconds: 100), () {
                _searchFocusNode.requestFocus();
              });
            }
          },
          validator: (value) {
            if (_paymentMethod == 'آجل' && _selectedCustomer == null) {
              return 'يجب تحديد العميل في البيع الآجل';
            }
            return null;
          },
        );
      },
      menuChildren: [
        // حقل البحث
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'ابحث عن عميل...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                      : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const Divider(height: 1),
        // قائمة العملاء
        SizedBox(
          height: 200, // ارتفاع ثابت للقائمة
          width: 400, // عرض ثابت للقائمة
          child:
              _searchResults.isEmpty
                  ? const Center(
                    child: Text(
                      'لا توجد نتائج',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final customer = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.person_outline, size: 20),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            customer.phone != null && customer.phone!.isNotEmpty
                                ? Text(customer.phone!)
                                : null,
                        onTap: () {
                          setState(() {
                            _selectedCustomer = customer;
                          });
                          // ***** إغلاق القائمة تلقائياً عند الاختيار *****
                          _menuController.close();
                        },
                        visualDensity: const VisualDensity(vertical: -4),
                      );
                    },
                  ),
        ),
        const Divider(height: 1),
        // زر إضافة عميل جديد
        ListTile(
          leading: const Icon(Icons.add, color: Colors.green, size: 20),
          title: const Text('إضافة عميل جديد'),
          onTap: () {
            // ***** إغلاق القائمة قبل فتح نافذة الإضافة *****
            _menuController.close();
            _showAndHandleAddCustomer();
          },
          visualDensity: const VisualDensity(vertical: -4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      contentPadding: const EdgeInsets.all(24),
      title: const Row(
        children: [
          Icon(Icons.payment, color: Colors.blue),
          SizedBox(width: 12),
          Text(
            'إتمام عملية البيع',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // إجمالي المبلغ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "المبلغ الإجمالي:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${widget.totalAmount.toStringAsFixed(2)} شيكل",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // طريقة الدفع
                const Text(
                  'طريقة الدفع:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'نقدي',
                          style: TextStyle(fontSize: 15),
                        ),
                        value: 'نقدي',
                        groupValue: _paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value!;
                            _paidAmountController.text = widget.totalAmount
                                .toStringAsFixed(2);
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'آجل',
                          style: TextStyle(fontSize: 15),
                        ),
                        value: 'آجل',
                        groupValue: _paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value!;
                            _paidAmountController.clear();
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // المبلغ المدفوع
                TextFormField(
                  controller: _paidAmountController,
                  enabled: _paymentMethod == 'آجل',
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.money),
                    filled: true,
                    fillColor:
                        _paymentMethod == 'نقدي'
                            ? Colors.grey[200]
                            : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال المبلغ المدفوع';
                    }
                    final paid = double.tryParse(value);
                    if (paid == null) {
                      return 'يرجى إدخال مبلغ صحيح';
                    }
                    if (paid < 0) {
                      return 'المبلغ لا يمكن أن يكون سالباً';
                    }
                    return null;
                  },
                ),

                if (_paymentMethod == 'آجل') ...[
                  const SizedBox(height: 20),
                  const Text(
                    'اختر العميل:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // استخدام القائمة المنسدلة مع البحث
                  _buildSearchableDropdown(),

                  // عرض العميل المختار
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCustomer!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_selectedCustomer!.phone != null)
                                  Text(
                                    _selectedCustomer!.phone!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedCustomer = null;
                                _searchController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _onConfirm,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('تأكيد الدفع', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
