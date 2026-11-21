using System.Text.Json;
using Microsoft.Extensions.Hosting;

namespace ECommerce.Infrastructure.Carts;

public sealed record AccountCartItem(
    int ProductId,
    int Quantity,
    string ProductName,
    decimal UnitPrice,
    string? Description,
    string? ImageUrl,
    int[]? CategoryIds,
    int Stock,
    bool StockTracked = false);

public interface IAccountCartStore
{
    Task<IReadOnlyList<AccountCartItem>> GetAsync(int customerId, CancellationToken cancellationToken);
    Task SaveAsync(int customerId, IReadOnlyList<AccountCartItem> items, CancellationToken cancellationToken);
}

/// <summary>Stores account carts on the API host, keyed by authenticated customer ID.</summary>
public sealed class JsonAccountCartStore : IAccountCartStore
{
    private readonly string _filePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Dictionary<int, List<AccountCartItem>>? _carts;

    public JsonAccountCartStore(IHostEnvironment environment) =>
        _filePath = Path.Combine(environment.ContentRootPath, "account-carts.json");

    public async Task<IReadOnlyList<AccountCartItem>> GetAsync(
        int customerId,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _carts!.TryGetValue(customerId, out var items)
                ? items.ToArray()
                : Array.Empty<AccountCartItem>();
        }
        finally { _gate.Release(); }
    }

    public async Task SaveAsync(
        int customerId,
        IReadOnlyList<AccountCartItem> items,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            _carts![customerId] = items.ToList();
            var temporaryPath = _filePath + ".tmp";
            await using (var stream = File.Create(temporaryPath))
                await JsonSerializer.SerializeAsync(stream, _carts, cancellationToken: cancellationToken);
            File.Move(temporaryPath, _filePath, overwrite: true);
        }
        finally { _gate.Release(); }
    }

    private async Task LoadAsync(CancellationToken cancellationToken)
    {
        if (_carts is not null) return;
        if (!File.Exists(_filePath))
        {
            _carts = new Dictionary<int, List<AccountCartItem>>();
            return;
        }

        await using var stream = File.OpenRead(_filePath);
        _carts = await JsonSerializer.DeserializeAsync<Dictionary<int, List<AccountCartItem>>>(
            stream, cancellationToken: cancellationToken) ?? new Dictionary<int, List<AccountCartItem>>();
    }
}
