import '../domain/cart_item.dart';
import '../domain/order.dart';
import 'order_repository.dart';

class CreateOrderUseCase {
  const CreateOrderUseCase(this._repository);
  final OrderRepository _repository;
  Future<OrderModel> call(List<CartItem> items) =>
      _repository.createOrder(items);
}

class GetCustomerOrdersUseCase {
  const GetCustomerOrdersUseCase(this._repository);
  final OrderRepository _repository;
  Future<List<OrderModel>> call() => _repository.getCustomerOrders();
}

class GetOrderDetailUseCase {
  const GetOrderDetailUseCase(this._repository);
  final OrderRepository _repository;
  Future<OrderModel?> call(int orderId) => _repository.getOrderDetail(orderId);
}
