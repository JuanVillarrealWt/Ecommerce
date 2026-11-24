using System.Text.Json;
using ECommerce.Application.Orders;
using ECommerce.Domain.Orders;
using Microsoft.Extensions.Hosting;

namespace ECommerce.Infrastructure.Orders;

public sealed class JsonOrderSnapshotStore : IOrderSnapshotStore
{
    private readonly string _filePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Dictionary<int, Order>? _snapshots;

    public JsonOrderSnapshotStore(IHostEnvironment environment) =>
        _filePath = Path.Combine(environment.ContentRootPath, "order-snapshots.json");

    public async Task<Order?> GetAsync(
        int orderId,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _snapshots!.GetValueOrDefault(orderId);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<Order> CaptureIfMissingAsync(
        Order order,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            if (!_snapshots!.TryGetValue(order.Id, out var snapshot))
            {
                snapshot = Copy(order);
                _snapshots[order.Id] = snapshot;
                await SaveAsync(cancellationToken);
            }

            return ApplyCurrentState(snapshot, order);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<IReadOnlyList<Order>> GetByPartnerIdAsync(
        int partnerId,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _snapshots!.Values
                .Where(order => order.PartnerId == partnerId)
                .ToList();
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task LoadAsync(CancellationToken cancellationToken)
    {
        if (_snapshots is not null) return;
        if (!File.Exists(_filePath))
        {
            _snapshots = [];
            return;
        }

        await using var stream = File.OpenRead(_filePath);
        _snapshots = await JsonSerializer.DeserializeAsync<Dictionary<int, Order>>(
            stream,
            cancellationToken: cancellationToken) ?? [];
    }

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        var temporaryPath = _filePath + ".tmp";
        await using (var stream = File.Create(temporaryPath))
        {
            await JsonSerializer.SerializeAsync(
                stream,
                _snapshots,
                cancellationToken: cancellationToken);
        }

        File.Move(temporaryPath, _filePath, overwrite: true);
    }

    private static Order Copy(Order order) => new(
        order.Id,
        order.Name,
        order.PartnerId,
        order.PartnerName,
        order.State,
        order.AmountTotal,
        order.CreatedAt,
        order.Items.Select(item => new OrderItem(
            item.ProductId,
            item.ProductName,
            item.Quantity,
            item.UnitPrice)).ToArray(),
        order.CurrencyCode,
        order.AmountUntaxed,
        order.AmountTax,
        order.Received);

    private static Order ApplyCurrentState(Order snapshot, Order current) => new(
        snapshot.Id,
        snapshot.Name,
        snapshot.PartnerId,
        snapshot.PartnerName,
        current.State,
        snapshot.AmountTotal,
        snapshot.CreatedAt,
        snapshot.Items,
        snapshot.CurrencyCode,
        snapshot.AmountUntaxed,
        snapshot.AmountTax,
        current.Received);
}
