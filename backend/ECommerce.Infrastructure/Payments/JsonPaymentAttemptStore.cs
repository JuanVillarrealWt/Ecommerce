using System.Text.Json;
using ECommerce.Application.Payments;
using Microsoft.Extensions.Hosting;

namespace ECommerce.Infrastructure.Payments;

public sealed class JsonPaymentAttemptStore : IPaymentAttemptStore
{
    private readonly string _filePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Dictionary<string, PaymentAttempt>? _attempts;

    public JsonPaymentAttemptStore(IHostEnvironment environment) =>
        _filePath = Path.Combine(environment.ContentRootPath, "payment-attempts.json");

    public async Task AddAsync(PaymentAttempt attempt, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            _attempts![attempt.Id] = attempt;
            await SaveAsync(cancellationToken);
        }
        finally { _gate.Release(); }
    }

    public async Task<PaymentAttempt?> GetAsync(string attemptId, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _attempts!.GetValueOrDefault(attemptId);
        }
        finally { _gate.Release(); }
    }

    public async Task<PaymentAttempt?> FindByPaymentIntentAsync(string paymentIntentId, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _attempts!.Values.FirstOrDefault(attempt => attempt.PaymentIntentId == paymentIntentId);
        }
        finally { _gate.Release(); }
    }

    public async Task<IReadOnlyList<PaymentAttempt>> GetByPartnerAsync(int partnerId, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            return _attempts!.Values.Where(attempt => attempt.PartnerId == partnerId && attempt.Status == "paid")
                .OrderByDescending(attempt => attempt.CreatedAt).ToArray();
        }
        finally { _gate.Release(); }
    }

    public async Task UpdateAsync(PaymentAttempt attempt, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await LoadAsync(cancellationToken);
            if (_attempts!.ContainsKey(attempt.Id))
            {
                var current = _attempts[attempt.Id];
                var status = current.Status == "paid" && attempt.Status != "paid"
                    ? current.Status
                    : attempt.Status;
                _attempts[attempt.Id] = attempt with { Status = status };
                await SaveAsync(cancellationToken);
            }
        }
        finally { _gate.Release(); }
    }

    private async Task LoadAsync(CancellationToken cancellationToken)
    {
        if (_attempts is not null) return;
        if (!File.Exists(_filePath))
        {
            _attempts = new Dictionary<string, PaymentAttempt>();
            return;
        }

        await using var stream = File.OpenRead(_filePath);
        _attempts = await JsonSerializer.DeserializeAsync<Dictionary<string, PaymentAttempt>>(
            stream, cancellationToken: cancellationToken) ?? new Dictionary<string, PaymentAttempt>();
    }

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        var temporaryPath = _filePath + ".tmp";
        await using (var stream = File.Create(temporaryPath))
            await JsonSerializer.SerializeAsync(stream, _attempts, cancellationToken: cancellationToken);
        File.Move(temporaryPath, _filePath, overwrite: true);
    }
}
