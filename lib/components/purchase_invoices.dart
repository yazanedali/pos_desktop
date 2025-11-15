import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import 'purchase_invoice_dialog.dart';
import 'purchase_invoice_details_dialog.dart';
import '../database/purchase_queries.dart';
import '../database/category_queries.dart';
import '../widgets/top_alert.dart';

class PurchaseInvoices extends StatefulWidget {
  const PurchaseInvoices({super.key});

  @override
  State<PurchaseInvoices> createState() => _PurchaseInvoicesState();
}

class _PurchaseInvoicesState extends State<PurchaseInvoices> {
  late Future<List<PurchaseInvoice>> _invoicesFuture;
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    // جلب الفئات والفواتير من قاعدة البيانات في نفس الوقت
    final categories = await CategoryQueries().getCategories();
    final invoicesFuture = PurchaseQueries().getPurchaseInvoices();

    setState(() {
      _categories = categories;
      _invoicesFuture = invoicesFuture;
      _isLoading = false;
    });
  }

  void _addInvoice(PurchaseInvoice invoice) async {
    try {
      await PurchaseQueries().insertPurchaseInvoice(invoice);
      TopAlert.showSuccess(
        // ignore: use_build_context_synchronously
        context: context,
        message: "تم إضافة فاتورة الشراء ${invoice.invoiceNumber} بنجاح",
      );
      _refreshData(); // تحديث القائمة
    } catch (e) {
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: "حدث خطأ: ${e.toString()}");
    }
  }

  void _updateInvoice(PurchaseInvoice invoice) async {
    try {
      await PurchaseQueries().updatePurchaseInvoice(invoice);
      TopAlert.showSuccess(
        // ignore: use_build_context_synchronously
        context: context,
        message: "تم تعديل الفاتورة ${invoice.invoiceNumber} بنجاح",
      );
      _refreshData(); // تحديث القائمة
    } catch (e) {
      TopAlert.showError(
        // ignore: use_build_context_synchronously
        context: context,
        message: "حدث خطأ أثناء التعديل: ${e.toString()}",
      );
    }
  }

  void _showEditInvoiceDialog(PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDialog(
            categories: _categories,
            invoiceToEdit: invoice, // تمرير الفاتورة هنا
            onSave: (updatedInvoice) {
              _updateInvoice(updatedInvoice);
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  void _deleteInvoice(int id) async {
    // يمكنك إضافة ديالوج تأكيد هنا
    try {
      await PurchaseQueries().deletePurchaseInvoice(id);
      // ignore: use_build_context_synchronously
      TopAlert.showSuccess(context: context, message: "تم حذف الفاتورة بنجاح");
      _refreshData(); // تحديث القائمة
    } catch (e) {
      TopAlert.showError(
        // ignore: use_build_context_synchronously
        context: context,
        message: "حدث خطأ أثناء الحذف: ${e.toString()}",
      );
    }
  }

  void _showInvoiceDetails(PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDetailsDialog(
            invoice: invoice,
            categories: _categories,
            onClose: () => Navigator.of(context).pop(),
          ),
    );
  }

  void _showAddInvoiceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDialog(
            categories: _categories,
            onSave: (invoice) {
              _addInvoice(invoice);
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Card - سيبقى كما هو تقريباً
        _buildHeader(),
        const SizedBox(height: 16),

        // Invoices List Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildListHeader(),
                const SizedBox(height: 16),
                _buildContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<PurchaseInvoice>>(
      future: _invoicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("حدث خطأ: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        } else {
          final invoices = snapshot.data!;
          return _buildInvoicesList(invoices);
        }
      },
    );
  }

  Widget _buildHeader() {
    // ... (كود الهيدر الخاص بك يمكن نقله هنا لترتيب الكود)
    // يمكنك تعديل عدد الفواتير ليعكس العدد الحقيقي من snapshot
    return Card(
      // ...
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ... عنوان "فواتير الشراء"
            ElevatedButton.icon(
              onPressed: _showAddInvoiceDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("إضافة فاتورة شراء"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    // ... كود عنوان القائمة
    return Row(/* ... */);
  }

  Widget _buildInvoicesList(List<PurchaseInvoice> invoices) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        return _buildInvoiceCard(invoices[index]);
      },
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                // ... (نفس تصميمك الحالي)
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${invoice.items.length} منتج",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${invoice.date} - ${invoice.time}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        invoice.supplier,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${invoice.total.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _showInvoiceDetails(invoice),
                      child: const Text("عرض التفاصيل"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showEditInvoiceDialog(invoice),
                      tooltip: 'تعديل الفاتورة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteInvoice(invoice.id!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "لا توجد فواتير شراء حتى الآن",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "قم بإضافة فاتورة شراء جديدة لتظهر هنا",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
