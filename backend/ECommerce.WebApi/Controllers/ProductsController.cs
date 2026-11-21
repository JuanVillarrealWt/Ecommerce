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

    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> Image(int id, CancellationToken cancellationToken)
    {
        var product = await getProduct.ExecuteAsync(id, cancellationToken);
        var source = product?.ImageUrl;
        if (string.IsNullOrWhiteSpace(source)) return NotFound();

        var marker = source.IndexOf(";base64,", StringComparison.OrdinalIgnoreCase);
        if (!source.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase) || marker < 0)
            return NotFound();

        try
        {
            Response.Headers.CacheControl = "public, max-age=86400";
            var contentType = source[5..marker];
            var bytes = Convert.FromBase64String(source[(marker + 8)..]);
            return File(bytes, contentType);
        }
        catch (FormatException)
        {
            return NotFound();
        }
    }
}
