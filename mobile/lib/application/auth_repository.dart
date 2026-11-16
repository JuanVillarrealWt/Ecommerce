import '../domain/customer.dart';

abstract interface class AuthRepository {
  Future<Customer> register(String name, String email, String password);
  Future<Customer> login(String email, String password);
  Future<void> logout();
  Customer? getCurrentCustomer();
  String? getAuthToken();
  bool get isAuthenticated;
}
