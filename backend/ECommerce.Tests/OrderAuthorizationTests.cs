using ECommerce.Application.Orders;
using ECommerce.Domain.Orders;

namespace ECommerce.Tests;

public class OrderAuthorizationTests
{
    private sealed class FakeOrderService(Dictionary<int, Order> orders) : IOrderService
    {
        public Task<Order> CreateOrderAsync(
            int partnerId,
            string clientOrderRef,
            IReadOnlyList<(int ProductId, int Quantity, decimal UnitPrice)> items,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<Order>> GetCustomerOrdersAsync(int partnerId, CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<Order>>(orders.Values.Where(o => o.PartnerId == partnerId).ToList());

        public Task<Order?> GetOrderByIdAsync(int orderId, CancellationToken cancellationToken = default) =>
            Task.FromResult(orders.TryGetValue(orderId, out var o) ? o : null);
    }

    [Fact]
    public async Task ExecuteAsync_WhenRequestingOrderFromAnotherCustomer_ThrowsUnauthorizedAccessException()
    {
        // Arrange (PA-04: Rechazar acceso a pedidos de otro cliente con identidad simulada)
        var orderBelongingToCustomer6 = new Order(
            1,
            "S00001",
            partnerId: 6,
            partnerName: "Consumidor final",
            state: "sale",
            amountTotal: 46.0m,
            createdAt: DateTime.UtcNow,
            items: new[] { new OrderItem(7, "PROD-TEST-001", 1, 10.0m) });

        var fakeOrderService = new FakeOrderService(new() { [1] = orderBelongingToCustomer6 });
        var useCase = new GetCustomerOrderDetail(fakeOrderService);

        // Act & Assert: El cliente autenticado simulado es ID 7 (otro contacto)
        var simulatedDifferentCustomerPartnerId = 7;

        var ex = await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            useCase.ExecuteAsync(orderId: 1, customerPartnerId: simulatedDifferentCustomerPartnerId));

        Assert.Contains("No tiene autorización", ex.Message);
    }

    [Fact]
    public async Task ExecuteAsync_WhenRequestingOwnOrder_ReturnsOrderSuccessfully()
    {
        // Arrange: El cliente solicita su propio pedido
        var order = new Order(
            1,
            "S00001",
            partnerId: 6,
            partnerName: "Consumidor final",
            state: "sale",
            amountTotal: 46.0m,
            createdAt: DateTime.UtcNow,
            items: new[] { new OrderItem(7, "PROD-TEST-001", 1, 10.0m) });

        var fakeOrderService = new FakeOrderService(new() { [1] = order });
        var useCase = new GetCustomerOrderDetail(fakeOrderService);

        // Act
        var result = await useCase.ExecuteAsync(orderId: 1, customerPartnerId: 6);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(1, result.Id);
        Assert.Equal(6, result.PartnerId);
    }

    [Fact]
    public async Task ExecuteAsync_WhenOrderDoesNotExist_ReturnsNull()
    {
        // Arrange: Pedido no existe
        var fakeOrderService = new FakeOrderService(new());
        var useCase = new GetCustomerOrderDetail(fakeOrderService);

        // Act
        var result = await useCase.ExecuteAsync(orderId: 999, customerPartnerId: 6);

        // Assert
        Assert.Null(result);
    }
}
