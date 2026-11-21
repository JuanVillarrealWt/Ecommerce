using ECommerce.Application.Orders;
using ECommerce.Application.Products;
using ECommerce.Domain.Orders;
using ECommerce.Domain.Products;

namespace ECommerce.Tests;

public class CreateOrderTests
{
    private sealed class FakeProductCatalog(Dictionary<int, Product> products) : IProductCatalog
    {
        public Task<IReadOnlyList<Product>> GetProductsAsync(int? categoryId = null, CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<Product>>(products.Values.ToList());

        public Task<Product?> GetProductAsync(int id, CancellationToken cancellationToken = default) =>
            Task.FromResult(products.TryGetValue(id, out var p) ? p : null);
    }

    private sealed class FakeOrderService : IOrderService
    {
        public bool CreateOrderCalled { get; private set; }

        public Task<Order> CreateOrderAsync(
            int partnerId,
            string clientOrderRef,
            IReadOnlyList<(int ProductId, int Quantity, decimal UnitPrice)> items,
            CancellationToken cancellationToken = default)
        {
            CreateOrderCalled = true;
            var orderItems = items.Select(i => new OrderItem(i.ProductId, $"Producto {i.ProductId}", i.Quantity, i.UnitPrice)).ToList();
            var total = orderItems.Sum(i => i.Subtotal);
            var order = new Order(101, "S00101", partnerId, "Cliente Test", "sale", total, DateTime.UtcNow, orderItems);
            return Task.FromResult(order);
        }

        public Task<IReadOnlyList<Order>> GetCustomerOrdersAsync(int partnerId, CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<Order>>(Array.Empty<Order>());

        public Task<Order?> GetOrderByIdAsync(int orderId, CancellationToken cancellationToken = default) =>
            Task.FromResult<Order?>(null);
    }

    [Fact]
    public async Task ExecuteAsync_WithEmptyItems_ThrowsArgumentException_AndDoesNotInvokeService()
    {
        // Arrange (PA-03: Validar pedido vacío)
        var fakeCatalog = new FakeProductCatalog(new());
        var fakeOrderService = new FakeOrderService();
        var useCase = new CreateOrder(fakeOrderService, fakeCatalog);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<ArgumentException>(() =>
            useCase.ExecuteAsync(6, "REF-001", Array.Empty<CreateOrderItemRequest>()));

        Assert.Contains("al menos un producto", ex.Message);
        Assert.False(fakeOrderService.CreateOrderCalled);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-5)]
    public async Task ExecuteAsync_WithInvalidQuantity_ThrowsArgumentOutOfRangeException_AndDoesNotInvokeService(int invalidQty)
    {
        // Arrange (PA-03: Validar cantidad inválida <= 0)
        var fakeCatalog = new FakeProductCatalog(new()
        {
            [7] = new Product(7, "Laptop Test", "Desc", 100m, null, new[] { 1 }, 50)
        });
        var fakeOrderService = new FakeOrderService();
        var useCase = new CreateOrder(fakeOrderService, fakeCatalog);

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            useCase.ExecuteAsync(6, "REF-002", new[] { new CreateOrderItemRequest(7, invalidQty) }));

        Assert.False(fakeOrderService.CreateOrderCalled);
    }

    [Fact]
    public async Task ExecuteAsync_WithQuantityExceedingStock_ThrowsInvalidOperationException()
    {
        // Arrange
        var fakeCatalog = new FakeProductCatalog(new()
        {
            [7] = new Product(7, "Laptop Test", "Desc", 100m, null, new[] { 1 }, 10)
        });
        var fakeOrderService = new FakeOrderService();
        var useCase = new CreateOrder(fakeOrderService, fakeCatalog);

        // Act & Assert (Solicitar 15 cuando hay 10 en stock)
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            useCase.ExecuteAsync(6, "REF-EXCEED", new[] { new CreateOrderItemRequest(7, 15) }));

        Assert.Contains("Stock insuficiente", ex.Message);
        Assert.False(fakeOrderService.CreateOrderCalled);
    }

    [Fact]
    public async Task ExecuteAsync_WithNonExistentProduct_ThrowsInvalidOperationException_AndDoesNotInvokeService()
    {
        // Arrange (PA-03: Validar productos no válidos o inexistentes en catálogo)
        var fakeCatalog = new FakeProductCatalog(new()); // Catálogo vacío
        var fakeOrderService = new FakeOrderService();
        var useCase = new CreateOrder(fakeOrderService, fakeCatalog);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            useCase.ExecuteAsync(6, "REF-003", new[] { new CreateOrderItemRequest(999, 2) }));

        Assert.Contains("no existe", ex.Message);
        Assert.False(fakeOrderService.CreateOrderCalled);
    }

    [Fact]
    public async Task ExecuteAsync_WithValidItems_InvokesCreation_AndReturnsConfirmedOrder()
    {
        // Arrange: Pedido válido
        var fakeCatalog = new FakeProductCatalog(new()
        {
            [7] = new Product(7, "PROD-TEST-001", "Desc 1", 10.0m, null, new[] { 1 }, 50),
            [8] = new Product(8, "PROD-TEST-002", "Desc 2", 15.0m, null, new[] { 1 }, 50)
        });
        var fakeOrderService = new FakeOrderService();
        var useCase = new CreateOrder(fakeOrderService, fakeCatalog);

        // Act
        var result = await useCase.ExecuteAsync(6, "PRUEBA-001", new[]
        {
            new CreateOrderItemRequest(7, 1),
            new CreateOrderItemRequest(8, 2)
        });

        // Assert
        Assert.True(fakeOrderService.CreateOrderCalled);
        Assert.NotNull(result);
        Assert.Equal(6, result.PartnerId);
        Assert.Equal(2, result.Items.Count);
        Assert.Equal(40.0m, result.AmountTotal); // 1*10 + 2*15 = 40
    }
}

