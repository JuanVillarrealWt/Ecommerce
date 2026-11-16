using ECommerce.Application.Categories;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/categories")]
public sealed class CategoriesController(GetCategories getCategories) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<CategoryResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<CategoryResponse>>> List(CancellationToken cancellationToken) =>
        Ok((await getCategories.ExecuteAsync(cancellationToken)).Select(CategoryResponse.From).ToArray());
}
