import '../domain/cart_item.dart';
import '../domain/order.dart';

abstract interface class OrderRepository {
  Future<OrderModel> createOrder(List<CartItem> items);
  Future<List<OrderModel>> getCustomerOrders();
  Future<OrderModel?> getOrderDetail(int orderId);
}
