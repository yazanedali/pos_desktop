import 'package:flutter/material.dart';
import 'sales_interface.dart';

class MultiTabSalesPage extends StatefulWidget {
  const MultiTabSalesPage({super.key});

  @override
  State<MultiTabSalesPage> createState() => _MultiTabSalesPageState();
}

class _MultiTabSalesPageState extends State<MultiTabSalesPage> {
  // قائمة تحتوي على مفاتيح فريدة لكل واجهة بيع عشان نفصل بينهم
  // كل عنصر يمثل "فاتورة مفتوحة"
  List<UniqueKey> _salesKeys = [UniqueKey()];
  int _selectedIndex = 0;

  void _addNewTab() {
    setState(() {
      _salesKeys.add(UniqueKey());
      _selectedIndex = _salesKeys.length - 1; // الانتقال للتاب الجديد مباشرة
    });
  }

  void _closeTab(int index) {
    if (_salesKeys.length <= 1) {
      // ممنوع تسكر آخر تبويبة، لازم يضل وحدة شغالة عالأقل
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يجب إبقاء نافذة بيع واحدة على الأقل مفتوحة"),
        ),
      );
      return;
    }

    setState(() {
      _salesKeys.removeAt(index);
      // تعديل الاندكس بعد الحذف عشان ما يصير خطأ
      if (_selectedIndex >= index && _selectedIndex > 0) {
        _selectedIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- شريط التبويبات العلوي ---
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // قائمة الفواتير المفتوحة
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _salesKeys.length,
                  itemBuilder: (context, index) {
                    final bool isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFF4A80F0)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.transparent
                                    : Colors.grey.shade300,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "فاتورة #${index + 1}",
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // زر الإغلاق
                            InkWell(
                              onTap: () => _closeTab(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color:
                                    isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // زر إضافة فاتورة جديدة
              const SizedBox(width: 8),
              Tooltip(
                message: "فاتورة جديدة (زبون جديد)",
                child: ElevatedButton.icon(
                  onPressed: _addNewTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9355F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("زبون جديد"),
                ),
              ),
            ],
          ),
        ),

        // --- محتوى الفاتورة المختارة ---
        // استخدمنا IndexedStack عشان يحافظ على حالة كل صفحة (ما يعمل ريفريش لما تقلب)
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children:
                _salesKeys.map((key) {
                  // بنمرر الـ key عشان فلاتر يعرف ان هاي صفحة مميزة عن غيرها
                  return SalesInterface(key: key);
                }).toList(),
          ),
        ),
      ],
    );
  }
}
