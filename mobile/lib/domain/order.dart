class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.name,
    required this.partnerId,
    required this.partnerName,
    required this.state,
    required this.amountTotal,
    required this.createdAt,
    required this.items,
  });

  final int id;
  final String name;
  final int partnerId;
  final String partnerName;
  final String state; // "draft", "sale", "cancel"
  final double amountTotal;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  bool get isConfirmed => state == 'sale';
}

