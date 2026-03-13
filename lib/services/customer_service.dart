import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CustomerService {
  static const String _boxName = 'customerBox';

  static Future<void> init() async {
    // Hive.initFlutter() is already called in AuthService, but safe to call again or skip if handled in main.
    // Ensure box is open
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  // Expose listenable for reactive UI
  static ValueListenable<Box> get listenable => _box.listenable();

  // Add a new customer
  static Future<void> addCustomer(Map<String, dynamic> customerData) async {
    // We can use the phone number as the key or auto-increment
    // Using auto-increment key for simplicity in list
    await _box.add(customerData);
  }

  // Get all customers
  static List<Map<dynamic, dynamic>> getCustomers() {
    return _box.values.map((e) => e as Map<dynamic, dynamic>).toList();
  }

  // Delete customer (optional, good to have)
  static Future<void> deleteCustomer(int index) async {
    await _box.deleteAt(index);
  }

  // Update customer payment status
  static Future<void> updateCustomerPayment(
    int index,
    List<int> paidMonths, [
    Map<String, double>? paymentAmounts,
  ]) async {
    final customer = _box.getAt(index) as Map;
    final updatedCustomer = Map<String, dynamic>.from(customer);
    updatedCustomer['payments'] = paidMonths;
    if (paymentAmounts != null) {
      updatedCustomer['paymentAmounts'] = paymentAmounts;
    }
    await _box.putAt(index, updatedCustomer);
  }
}
