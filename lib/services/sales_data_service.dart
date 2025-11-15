import '../models/sales_models.dart';

class SalesDataService {
  static List<Product> getMockProducts() {
    return [
      Product(
        id: "1",
        name: "كوكا كولا",
        price: 2.5,
        barcode: "12345",
        stock: 50,
      ),
      Product(id: "2", name: "شيبس", price: 1.5, barcode: "67890", stock: 30),
      Product(
        id: "3",
        name: "شوكولاتة",
        price: 3.0,
        barcode: "11111",
        stock: 25,
      ),
      Product(
        id: "4",
        name: "عصير برتقال",
        price: 4.0,
        barcode: "22222",
        stock: 20,
      ),
    ];
  }

  static String generateInvoiceNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time = now.millisecondsSinceEpoch.toString().substring(8);
    return 'INV-$date-$time';
  }
}
