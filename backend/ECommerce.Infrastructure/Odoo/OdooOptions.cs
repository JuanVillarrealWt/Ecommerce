namespace ECommerce.Infrastructure.Odoo;

public sealed class OdooOptions
{
    public const string SectionName = "Odoo";
    public string BaseUrl { get; init; } = "http://localhost:8069";
    public string Database { get; init; } = "";
    public string ApiKey { get; init; } = "";
}
