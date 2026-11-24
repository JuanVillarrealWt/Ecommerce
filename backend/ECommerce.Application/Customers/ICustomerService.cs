using ECommerce.Domain.Customers;
using ECommerce.Application.Payments;

namespace ECommerce.Application.Customers;

public interface ICustomerService : IPaymentCustomerProfileStore
{
    Task<Customer> RegisterAsync(string name, string email, string password, string province, string phone, CancellationToken cancellationToken = default);
    Task<(Customer Customer, string Token)> LoginAsync(string email, string password, CancellationToken cancellationToken = default);
    Task<Customer?> GetCustomerByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<Customer> UpdateProfileAsync(int id, string name, string province, string phone, CancellationToken cancellationToken = default);
    Task UpdatePrimaryAddressAsync(int partnerId, string street, string city, string province, string postalCode, string phone, CancellationToken cancellationToken = default);
}

