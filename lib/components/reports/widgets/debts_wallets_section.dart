import 'package:flutter/material.dart';
import 'package:pos_desktop/models/report_models_new.dart';

class DebtsWalletsSection extends StatelessWidget {
  final List<DebtorStat> debtors;
  final List<WalletStat> wallets;

  const DebtsWalletsSection({
    Key? key,
    required this.debtors,
    required this.wallets,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // قسم الديون (لي)
        Expanded(
          child: _buildListCard(
            title: 'أعلى الديون (لنا)',
            icon: Icons.arrow_downward,
            iconColor: Colors.red,
            children:
                debtors.isEmpty
                    ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد ديون'),
                      ),
                    ]
                    : debtors
                        .map(
                          (d) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              child: Text(
                                d.customerName[0],
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            title: Text(d.customerName),
                            subtitle: Text(d.lastTransactionDate),
                            trailing: Text(
                              d.totalDebt.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        )
                        .toList(),
          ),
        ),
        const SizedBox(width: 16),
        // قسم المحافظ (علي)
        Expanded(
          child: _buildListCard(
            title: 'أرصدة المحافظ (علينا)',
            icon: Icons.arrow_upward,
            iconColor: Colors.green,
            children:
                wallets.isEmpty
                    ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد محافظ دائنة'),
                      ),
                    ]
                    : wallets
                        .map(
                          (w) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              child: Text(
                                w.customerName[0],
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            title: Text(w.customerName),
                            trailing: Text(
                              w.balance.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        )
                        .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
        ],
      ),
    );
  }
}
