using ECommerce.Domain.Customers;

namespace ECommerce.Application.Customers;

public interface ICustomerService
{
    Task<Customer> RegisterAsync(string name, string email, string password, string province, string phone, CancellationToken cancellationToken = default);
    Task<(Customer Customer, string Token)> LoginAsync(string email, string password, CancellationToken cancellationToken = default);
    Task<Customer?> GetCustomerByIdAsync(int id, CancellationToken cancellationToken = default);
}

