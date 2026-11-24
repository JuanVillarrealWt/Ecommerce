import '../domain/cart_item.dart';
import '../domain/checkout_payment.dart';
import 'checkout_repository.dart';

class StartCheckoutUseCase {
  const StartCheckoutUseCase(this._repository);
  final CheckoutRepository _repository;
  Future<CheckoutPayment> call(
    List<CartItem> items, {
    String? couponCode,
    String? savedAddressId,
  }) => _repository.startCheckout(
    items,
    couponCode: couponCode,
    savedAddressId: savedAddressId,
  );

  Future<String> prepareConfirmation(String attemptId) =>
      _repository.prepareConfirmation(attemptId);
}

class GetCheckoutStatusUseCase {
  const GetCheckoutStatusUseCase(this._repository);
  final CheckoutRepository _repository;
  Future<CheckoutPaymentStatus> call(String attemptId) =>
      _repository.getStatus(attemptId);
}
