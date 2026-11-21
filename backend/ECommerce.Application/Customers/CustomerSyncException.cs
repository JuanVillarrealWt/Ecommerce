namespace ECommerce.Application.Customers;

public sealed class CustomerSyncException(string message, Exception? innerException = null)
    : Exception(message, innerException);
