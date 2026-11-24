namespace ECommerce.Application.CustomerFeatures;

public sealed class ManageCustomerFeatures(ICustomerFeaturesStore store)
{
    private static readonly SemaphoreSlim MutationLock = new(1, 1);

    public Task<CustomerFeaturesData> GetAsync(int partnerId, CancellationToken cancellationToken = default) =>
        store.GetAsync(ValidatePartnerId(partnerId), cancellationToken);

    public async Task<CustomerFeaturesData> UpdateAsync(
        int partnerId,
        Action<CustomerFeaturesData> update,
        CancellationToken cancellationToken = default)
    {
        ValidatePartnerId(partnerId);
        await MutationLock.WaitAsync(cancellationToken);
        try
        {
            var data = await store.GetAsync(partnerId, cancellationToken);
            update(data);
            await store.SaveAsync(partnerId, data, cancellationToken);
            return data;
        }
        finally
        {
            MutationLock.Release();
        }
    }

    public Task<IReadOnlyList<ProductReview>> GetProductReviewsAsync(int productId, CancellationToken cancellationToken = default) =>
        productId > 0 ? store.GetProductReviewsAsync(productId, cancellationToken) : Task.FromResult<IReadOnlyList<ProductReview>>([]);

    private static int ValidatePartnerId(int partnerId) => partnerId > 0
        ? partnerId
        : throw new ArgumentOutOfRangeException(nameof(partnerId));
}
