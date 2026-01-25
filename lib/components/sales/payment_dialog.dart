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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (result != null && mounted) {
      try {
        // تحويل الـ Map إلى كائن Customer
        final newCustomer = Customer(
          name: result['name'] ?? '',
          phone: result['phone'],
          address: result['address'],
        );

        final newId = await _customerQueries.insertCustomer(newCustomer);

        final newCompleteCustomer = Customer(
          id: newId,
          name: newCustomer.name,
          phone: newCustomer.phone,
          address: newCustomer.address,
        );

        setState(() {
          _availableCustomers.add(newCompleteCustomer);
          _searchResults = _availableCustomers;
          _selectedCustomer = newCompleteCustomer;
          _searchController.clear();
        });

        TopAlert.showSuccess(
          // ignore: use_build_context_synchronously
          context: context,
          message: 'تمت إضافة العميل واختياره',
        );
      } catch (e) {
        TopAlert.showError(
          // ignore: use_build_context_synchronously
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

  // بناء حقل البحث ونتائج البحث
  Widget _buildCustomerSelection() {
    if (_selectedCustomer != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
                      _searchResults =
                          _availableCustomers; // إعادة تعيين النتائج
                    });
                    // إعادة التركيز لحقل البحث
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _searchFocusNode.requestFocus();
                    });
                  },
                ),
              ],
            ),
            // عرض رصيد المحفظة إذا كان الخيار "من الرصيد"
            if (_paymentMethod == 'من الرصيد') ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("رصيد المحفظة المتاح:"),
                  Text(
                    "${_selectedCustomer!.walletBalance.toStringAsFixed(2)} شيكل",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          _selectedCustomer!.walletBalance >=
                                  double.parse(
                                    _paidAmountController.text.isEmpty
                                        ? "0"
                                        : _paidAmountController.text,
                                  )
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // حقل البحث
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true, // التركيز التلقائي هنا
          decoration: InputDecoration(
            hintText: 'ابحث عن عميل بالاسم أو الهاتف...',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                // زر إضافة عميل جديد بجانب البحث
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'إضافة عميل جديد',
                  onPressed: _showAndHandleAddCustomer,
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),

        // نتائج البحث
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
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
                  },
                  visualDensity: const VisualDensity(vertical: -2),
                );
              },
            ),
          ),
        ] else if (_searchController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'لا توجد نتائج مطابقة',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      contentPadding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 16),

                // طريقة الدفع
                const Text(
                  'طريقة الدفع:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'من الرصيد',
                          style: TextStyle(fontSize: 15),
                        ),
                        value: 'من الرصيد',
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
                  ],
                ),
                const SizedBox(height: 12),

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
                      horizontal: 12,
                      vertical: 12,
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
                    if (_paymentMethod == 'من الرصيد' &&
                        _selectedCustomer != null) {
                      if (paid > _selectedCustomer!.walletBalance) {
                        return 'رصيد العميل غير كافي';
                      }
                    }
                    return null;
                  },
                ),

                if (_paymentMethod == 'آجل' ||
                    _paymentMethod == 'من الرصيد') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'اختر العميل:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // استخدام اختيار العميل المباشر
                  _buildCustomerSelection(),
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
