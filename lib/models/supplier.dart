class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? createdAt;
  // هذا الحقل غير موجود في جدول الموردين مباشرة، بل يتم حسابه
  // من خلال الفواتير (مثل العميل)
  // balance > 0 : نحن مدينون له (له مصاري عندنا)
  // balance < 0 : هو مدين لنا (لنا مصاري عنده - حالة نادرة في الموردين لكن ممكنة المرتجعات)
  final double? balance; 

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
    this.balance,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'created_at': createdAt,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      createdAt: map['created_at'],
      balance: map['balance'] != null ? (map['balance'] as num).toDouble() : 0.0,
    );
  }
}
