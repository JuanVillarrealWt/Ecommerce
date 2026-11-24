class CheckoutPayment {
  const CheckoutPayment({
    required this.attemptId,
    required this.clientSecret,
    required this.customerId,
    required this.customerSessionClientSecret,
    required this.orderName,
    required this.amountTotal,
    required this.currency,
  });

  final String attemptId;
  final String clientSecret;
  final String customerId;
  final String customerSessionClientSecret;
  final String orderName;
  final double amountTotal;
  final String currency;

  factory CheckoutPayment.fromJson(Map<String, dynamic> json) =>
      CheckoutPayment(
        attemptId: json['attemptId'] as String,
        clientSecret: json['clientSecret'] as String,
        customerId: json['customerId'] as String,
        customerSessionClientSecret:
            json['customerSessionClientSecret'] as String,
        orderName: json['orderName'] as String,
        amountTotal: (json['amountTotal'] as num).toDouble(),
        currency: json['currency'] as String,
      );
}

class CheckoutPaymentStatus {
  const CheckoutPaymentStatus({
    required this.attemptId,
    required this.orderName,
    required this.amountTotal,
    required this.currency,
    required this.status,
  });

  final String attemptId;
  final String orderName;
  final double amountTotal;
  final String currency;
  final String status;

  factory CheckoutPaymentStatus.fromJson(Map<String, dynamic> json) =>
      CheckoutPaymentStatus(
        attemptId: json['attemptId'] as String,
        orderName: json['orderName'] as String,
        amountTotal: (json['amountTotal'] as num).toDouble(),
        currency: json['currency'] as String,
        status: json['status'] as String,
      );
}
