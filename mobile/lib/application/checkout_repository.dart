import '../domain/cart_item.dart';
import '../domain/checkout_payment.dart';

abstract interface class CheckoutRepository {
  Future<CheckoutPayment> startCheckout(
    List<CartItem> items, {
    String? couponCode,
    String? savedAddressId,
  });
  Future<String> prepareConfirmation(String attemptId);
  Future<CheckoutPaymentStatus> getStatus(String attemptId);
}
