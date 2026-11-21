import '../domain/customer.dart';
import 'auth_repository.dart';

class RegisterCustomerUseCase {
  const RegisterCustomerUseCase(this._repository);
  final AuthRepository _repository;
  Future<Customer> call(String name, String email, String password, String province, String phone) =>
      _repository.register(name, email, password, province, phone);
}

class LoginCustomerUseCase {
  const LoginCustomerUseCase(this._repository);
  final AuthRepository _repository;
  Future<Customer> call(String email, String password) =>
      _repository.login(email, password);
}

class LogoutCustomerUseCase {
  const LogoutCustomerUseCase(this._repository);
  final AuthRepository _repository;
  Future<void> call() => _repository.logout();
}

class GetCurrentCustomerUseCase {
  const GetCurrentCustomerUseCase(this._repository);
  final AuthRepository _repository;
  Customer? call() => _repository.getCurrentCustomer();
  bool get isAuthenticated => _repository.isAuthenticated;
}

