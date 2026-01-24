import 'package:flutter/foundation.dart';
import 'package:pos_desktop/database/product_queries.dart';

class StockAlertService {
  static final StockAlertService _instance = StockAlertService._internal();
  factory StockAlertService() => _instance;
  StockAlertService._internal();

  final ProductQueries _productQueries = ProductQueries();

  // ValueNotifier to let listeners (UI) know when count changes
  final ValueNotifier<int> alertCountNotifier = ValueNotifier<int>(0);

  // Method to force check alerts from Database
  Future<void> checkAlerts() async {
    try {
      final count = await _productQueries.getLowStockCount();
      alertCountNotifier.value = count;
    } catch (e) {
      print('Error checking alerts: $e');
    }
  }
}
