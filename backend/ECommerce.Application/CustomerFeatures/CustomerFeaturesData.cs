namespace ECommerce.Application.CustomerFeatures;

public sealed class CustomerFeaturesData
{
    public List<int> FavoriteProductIds { get; set; } = [];
    public List<Wishlist> Wishlists { get; set; } = [];
    public List<SavedAddress> Addresses { get; set; } = [];
    public List<ProductReview> Reviews { get; set; } = [];
    public List<CustomerNotification> Notifications { get; set; } = [];
    public List<int> ReceivedOrderIds { get; set; } = [];
    public Dictionary<int, string> OrderStates { get; set; } = [];
    public List<int> PurchasedProductIds { get; set; } = [];
}

public sealed record Wishlist(
    Guid Id,
    string Name,
    List<int> ProductIds,
    string? ShareToken,
    DateTime CreatedAt);

public sealed record SavedAddress(
    Guid Id,
    string Label,
    string Recipient,
    string Street,
    string City,
    string Province,
    string PostalCode,
    string Phone,
    bool IsDefault,
    int? OdooPartnerId = null);

public sealed record SaveAddressRequest(
    string Label,
    string Recipient,
    string Street,
    string City,
    string Province,
    string PostalCode,
    string Phone,
    bool IsDefault);

public sealed record ProductReview(
    Guid Id,
    int PartnerId,
    string CustomerName,
    int ProductId,
    int OrderId,
    int Rating,
    string Comment,
    DateTime CreatedAt);

public sealed record CustomerNotification(
    Guid Id,
    string Type,
    string Title,
    string Message,
    int? OrderId,
    DateTime CreatedAt,
    bool IsRead);

public interface ICustomerFeaturesStore
{
    Task<CustomerFeaturesData> GetAsync(int partnerId, CancellationToken cancellationToken = default);
    Task SaveAsync(int partnerId, CustomerFeaturesData data, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ProductReview>> GetProductReviewsAsync(int productId, CancellationToken cancellationToken = default);
}
