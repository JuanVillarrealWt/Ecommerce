using System.Text.Json;
using ECommerce.Application.CustomerFeatures;
using Microsoft.Extensions.Hosting;

namespace ECommerce.Infrastructure.CustomerFeatures;

public sealed class JsonCustomerFeaturesStore(IHostEnvironment environment) : ICustomerFeaturesStore
{
    private readonly string _storagePath = Path.Combine(environment.ContentRootPath, "customer-features.json");
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    private Dictionary<int, CustomerFeaturesData>? _cache;

    public async Task<CustomerFeaturesData> GetAsync(int partnerId, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var accounts = await LoadAsync(cancellationToken);
            return accounts.TryGetValue(partnerId, out var data)
                ? Clone(data)
                : new CustomerFeaturesData();
        }
        finally { _semaphore.Release(); }
    }

    public async Task SaveAsync(int partnerId, CustomerFeaturesData data, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var accounts = await LoadAsync(cancellationToken);
            accounts[partnerId] = Clone(data);
            await WriteAsync(accounts, cancellationToken);
        }
        finally { _semaphore.Release(); }
    }

    public async Task<IReadOnlyList<ProductReview>> GetProductReviewsAsync(int productId, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var accounts = await LoadAsync(cancellationToken);
            return accounts.Values.SelectMany(account => account.Reviews)
                .Where(review => review.ProductId == productId)
                .OrderByDescending(review => review.CreatedAt).ToArray();
        }
        finally { _semaphore.Release(); }
    }

    private async Task<Dictionary<int, CustomerFeaturesData>> LoadAsync(CancellationToken cancellationToken)
    {
        if (_cache is not null) return _cache;
        if (!File.Exists(_storagePath)) return _cache = [];
        var json = await File.ReadAllTextAsync(_storagePath, cancellationToken);
        _cache = JsonSerializer.Deserialize<Dictionary<int, CustomerFeaturesData>>(json) ?? [];
        if (_cache.Values.Any(account => account.Wishlists.Count > 0))
        {
            foreach (var account in _cache.Values) account.Wishlists.Clear();
            await WriteAsync(_cache, cancellationToken);
        }
        return _cache;
    }

    private async Task WriteAsync(Dictionary<int, CustomerFeaturesData> accounts, CancellationToken cancellationToken)
    {
        var temporaryPath = _storagePath + ".tmp";
        var json = JsonSerializer.Serialize(accounts, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(temporaryPath, json, cancellationToken);
        File.Move(temporaryPath, _storagePath, overwrite: true);
    }

    private static CustomerFeaturesData Clone(CustomerFeaturesData data) => new()
    {
        FavoriteProductIds = data.FavoriteProductIds.ToList(),
        Wishlists = data.Wishlists.Select(item => item with { ProductIds = item.ProductIds.ToList() }).ToList(),
        Addresses = data.Addresses.ToList(),
        Reviews = data.Reviews.ToList(),
        Notifications = data.Notifications.ToList(),
        OrderStates = new Dictionary<int, string>(data.OrderStates),
        ReceivedOrderIds = data.ReceivedOrderIds?.ToList() ?? []
    };
}
