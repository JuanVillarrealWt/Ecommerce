using ECommerce.Application.Products;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/products")]
public sealed class ProductsController(GetProducts getProducts, GetProduct getProduct) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<ProductResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ProductResponse>>> List([FromQuery] int? categoryId, CancellationToken cancellationToken) =>
        Ok((await getProducts.ExecuteAsync(categoryId, cancellationToken)).Select(ProductResponse.From).ToArray());

    [HttpGet("{id:int}")]
    [ProducesResponseType<ProductResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductResponse>> Detail(int id, CancellationToken cancellationToken)
    {
        var product = await getProduct.ExecuteAsync(id, cancellationToken);
        return product is null ? NotFound() : Ok(ProductResponse.From(product));
    }
}
