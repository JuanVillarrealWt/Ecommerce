abstract interface class CustomerFeaturesRepository {
  Future<Map<String, dynamic>> load();
  Future<void> addFavorite(int productId);
  Future<void> removeFavorite(int productId);
  Future<Map<String, dynamic>> saveAddress(Map<String, dynamic> address);
  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> address,
  );
  Future<void> deleteAddress(String id);
  Future<void> markNotificationRead(String id);
  Future<List<Map<String, dynamic>>> paymentHistory();
  Future<void> submitReview({
    required int productId,
    required int orderId,
    required int rating,
    required String comment,
  });
  Future<int?> reviewOrderId(int productId);
  Future<void> deleteReview(int productId);
  Future<List<Map<String, dynamic>>> productReviews(int productId);
}
