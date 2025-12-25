// models/customer.dart

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? createdAt;
  final double walletBalance; // <-- الرصيد (موجب = له مصاري، سالب = عليه مصاري - لكن غالبا هنا نستخدمه كرصيد إيجابي والدين يحسب من الفواتير)

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
    this.walletBalance = 0.0,
  });

  // دالة لتحويل كائن العميل إلى خريطة (Map) لحفظه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'created_at': createdAt,
      'wallet_balance': walletBalance,
    };
  }

  // دالة لإنشاء كائن عميل من خريطة (Map) قادمة من قاعدة البيانات
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      createdAt: map['created_at'],
      walletBalance: (map['wallet_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
