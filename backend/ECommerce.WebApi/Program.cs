using ECommerce.Application.Categories;
using ECommerce.Application.Customers;
using ECommerce.Application.Orders;
using ECommerce.Application.Products;
using ECommerce.Application.CustomerFeatures;
using ECommerce.Infrastructure.Auth;
using ECommerce.Infrastructure.Carts;
using ECommerce.Infrastructure.Odoo;
using ECommerce.Infrastructure.Payments;
using ECommerce.Infrastructure.CustomerFeatures;
using ECommerce.Infrastructure.Orders;
using ECommerce.Application.Payments;
using ECommerce.WebApi.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

// Configuración de Odoo
builder.Services.Configure<OdooOptions>(builder.Configuration.GetSection(OdooOptions.SectionName));
builder.Services.Configure<StripePaymentOptions>(builder.Configuration.GetSection(StripePaymentOptions.SectionName));

// Clientes HTTP hacia Odoo
builder.Services.AddHttpClient<IProductCatalog, OdooProductCatalog>((sp, client) => ConfigureOdooHttpClient(client, builder.Configuration));
builder.Services.AddHttpClient<ICategoryCatalog, OdooCategoryCatalog>((sp, client) => ConfigureOdooHttpClient(client, builder.Configuration));
builder.Services.AddHttpClient<IOrderService, OdooOrderService>((sp, client) => ConfigureOdooHttpClient(client, builder.Configuration));
builder.Services.AddHttpClient<ICustomerService, CustomerService>((sp, client) => ConfigureOdooHttpClient(client, builder.Configuration));
builder.Services.AddHttpClient<IPaymentGateway, StripePaymentGateway>();
builder.Services.AddSingleton<IPaymentAttemptStore, JsonPaymentAttemptStore>();
builder.Services.AddSingleton<IAccountCartStore, JsonAccountCartStore>();
builder.Services.AddSingleton<ICustomerFeaturesStore, JsonCustomerFeaturesStore>();
builder.Services.AddSingleton<IOrderSnapshotStore, JsonOrderSnapshotStore>();

// Casos de uso de la aplicación
builder.Services.AddScoped<GetProducts>();
builder.Services.AddScoped<GetProduct>();
builder.Services.AddScoped<ManageCustomerFeatures>();
builder.Services.AddScoped<GetCategories>();
builder.Services.AddScoped<RegisterCustomer>();
builder.Services.AddScoped<LoginCustomer>();
builder.Services.AddScoped<CreateOrder>();
builder.Services.AddScoped<GetCustomerOrders>();
builder.Services.AddScoped<GetCustomerOrderDetail>();
builder.Services.AddScoped<ProcessPaymentWebhook>();
builder.Services.AddScoped<PrepareCheckoutConfirmation>();
builder.Services.AddScoped(sp => new StartCheckout(
    sp.GetRequiredService<CreateOrder>(),
    sp.GetRequiredService<IPaymentGateway>(),
    sp.GetRequiredService<IPaymentAttemptStore>(),
    sp.GetRequiredService<ICustomerService>(),
    builder.Configuration.GetSection("DiscountCoupons").Get<List<DiscountCoupon>>() ?? [],
    builder.Configuration[$"{StripePaymentOptions.SectionName}:Currency"] ?? "usd"));

// Autenticación por token Bearer (JWT)
builder.Services.AddAuthentication(SimpleTokenAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, SimpleTokenAuthenticationHandler>(SimpleTokenAuthenticationHandler.SchemeName, null);
builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddProblemDetails();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Entre Cumbres E-Commerce API",
        Version = "v1",
        Description = "API para catálogo, clientes, direcciones, pedidos y pagos."
    });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "Token de acceso de la API",
        In = ParameterLocation.Header,
        Description = "Pega aquí el token que devuelve /api/auth/login."
    });
    options.OperationFilter<AuthorizeOperationFilter>();
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "Entre Cumbres API v1");
    options.DocumentTitle = "Entre Cumbres API";
});

// Manejo global de excepciones amigable con formato ProblemDetails
app.UseExceptionHandler(exceptionApp =>
{
    exceptionApp.Run(async context =>
    {
        var exFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerPathFeature>();
        var err = exFeature?.Error;
        app.Logger.LogError(err, "Excepción no controlada: {Message}", err?.Message);

        context.Response.ContentType = "application/problem+json";
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        var problem = new Microsoft.AspNetCore.Mvc.ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title = "Error interno del servidor",
            Detail = err?.Message ?? "Ocurrió un error inesperado al procesar la solicitud con el ERP u origen de datos."
        };
        await context.Response.WriteAsJsonAsync(problem);
    });
});

app.UseAuthentication();
app.UseCors();
app.UseAuthorization();

// Página visual de documentación interactiva de la API (/doc o /swagger)
app.MapGet("/doc", () => Results.Content("""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>E-Commerce API - Documentación</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; color: #222; background: #fdfdfd; line-height: 1.6; }
        h1 { color: #1e3a8a; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px; }
        .tag { display: inline-block; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 13px; color: white; margin-right: 8px; }
        .get { background: #0284c7; }
        .post { background: #16a34a; }
        .endpoint { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; margin-bottom: 12px; }
        .route { font-family: monospace; font-size: 15px; font-weight: bold; }
        .auth { background: #fee2e2; color: #991b1b; padding: 2px 6px; border-radius: 4px; font-size: 12px; font-weight: normal; margin-left: 8px; }
        pre { background: #0f172a; color: #f8fafc; padding: 12px; border-radius: 6px; overflow-x: auto; font-size: 13px; }
    </style>
</head>
<body>
    <h1>API E-Commerce Móvil (ASP.NET Core .NET 10)</h1>
    <p>Documentación de contratos REST para integración con Flutter y Odoo 20 Community.</p>

    <h2>Catálogo y Categorías</h2>
    <div class="endpoint">
        <span class="tag get">GET</span><span class="route">/api/products</span>
        <p>Lista productos activos en Odoo. Admite filtro opcional por categoría: <code>/api/products?categoryId=X</code></p>
    </div>
    <div class="endpoint">
        <span class="tag get">GET</span><span class="route">/api/products/{id}</span>
        <p>Obtiene el detalle completo de un producto por ID.</p>
    </div>
    <div class="endpoint">
        <span class="tag get">GET</span><span class="route">/api/categories</span>
        <p>Lista categorías de productos registradas en Odoo (<code>product.category</code>).</p>
    </div>

    <h2>Autenticación de Clientes</h2>
    <div class="endpoint">
        <span class="tag post">POST</span><span class="route">/api/auth/register</span>
        <p>Registra un nuevo cliente, lo vincula a Odoo (<code>res.partner</code>) y guarda credenciales.</p>
        <pre>{ "name": "Juan Perez", "email": "juan@example.com", "password": "password123" }</pre>
    </div>
    <div class="endpoint">
        <span class="tag post">POST</span><span class="route">/api/auth/login</span>
        <p>Inicia sesión y genera token Bearer (JWT) con el <code>partner_id</code>.</p>
        <pre>{ "email": "juan@example.com", "password": "password123" }</pre>
    </div>

    <h2>Pedidos (Requiere Token Bearer)</h2>
    <div class="endpoint">
        <span class="tag post">POST</span><span class="route">/api/checkout/payments</span><span class="auth">Requiere Auth</span>
        <p>Valida el carrito, crea una cotización y devuelve el secreto del PaymentIntent de Stripe. Odoo confirma el pedido solo después del webhook de pago.</p>
        <pre>{ "items": [ { "productId": 7, "quantity": 1 }, { "productId": 8, "quantity": 2 } ] }</pre>
    </div>
    <div class="endpoint">
        <span class="tag post">POST</span><span class="route">/api/checkout/webhook</span>
        <p>Recibe la notificación firmada de Stripe para confirmar las órdenes pagadas.</p>
    </div>
    <div class="endpoint">
        <span class="tag get">GET</span><span class="route">/api/orders</span><span class="auth">Requiere Auth</span>
        <p>Lista el historial de pedidos pertenecientes al cliente autenticado.</p>
    </div>
    <div class="endpoint">
        <span class="tag get">GET</span><span class="route">/api/orders/{id}</span><span class="auth">Requiere Auth</span>
        <p>Detalle de un pedido. Deniega acceso (403) si pertenece a otro cliente.</p>
    </div>
</body>
</html>
""", "text/html"));

app.MapControllers();

app.Run();

static void ConfigureOdooHttpClient(HttpClient client, IConfiguration config)
{
    var baseUrl = config["Odoo:BaseUrl"] ?? "http://localhost:8069";
    client.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(25);
}

sealed class AuthorizeOperationFilter : Swashbuckle.AspNetCore.SwaggerGen.IOperationFilter
{
    public void Apply(OpenApiOperation operation, Swashbuckle.AspNetCore.SwaggerGen.OperationFilterContext context)
    {
        var method = context.MethodInfo;
        var controller = method.DeclaringType;
        var isAnonymous = method.IsDefined(typeof(AllowAnonymousAttribute), inherit: true) ||
                          controller?.IsDefined(typeof(AllowAnonymousAttribute), inherit: true) == true;
        var requiresAuthorization = method.IsDefined(typeof(AuthorizeAttribute), inherit: true) ||
                                   controller?.IsDefined(typeof(AuthorizeAttribute), inherit: true) == true;

        if (isAnonymous || !requiresAuthorization) return;

        operation.Security =
        [
            new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", context.Document)] = []
            }
        ];
    }
}
