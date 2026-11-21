using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace ECommerce.Infrastructure.Auth;

public sealed class SimpleTokenService
{
    private static readonly byte[] SecretKey = Encoding.UTF8.GetBytes(
        Environment.GetEnvironmentVariable("Jwt__Secret") ??
        "DevelopmentOnly_ECommerce_Jwt_Secret_Configure_Jwt__Secret_In_Env");

    public static string GenerateToken(int customerId, string name, string email, int partnerId)
    {
        var header = new { alg = "HS256", typ = "JWT" };
        var payload = new Dictionary<string, object>
        {
            ["sub"] = customerId.ToString(),
            ["name"] = name,
            ["email"] = email,
            ["partner_id"] = partnerId,
            ["exp"] = DateTimeOffset.UtcNow.AddDays(7).ToUnixTimeSeconds()
        };

        var headerBase64 = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(header));
        var payloadBase64 = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(payload));

        var stringToSign = $"{headerBase64}.{payloadBase64}";
        using var hmac = new HMACSHA256(SecretKey);
        var signature = Base64UrlEncode(hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign)));

        return $"{stringToSign}.{signature}";
    }

    public static ClaimsPrincipal? ValidateToken(string token)
    {
        try
        {
            var parts = token.Split('.');
            if (parts.Length != 3) return null;

            var stringToSign = $"{parts[0]}.{parts[1]}";
            using var hmac = new HMACSHA256(SecretKey);
            var expectedSignature = Base64UrlEncode(hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign)));

            if (parts[2] != expectedSignature) return null;

            var payloadBytes = Base64UrlDecode(parts[1]);
            using var doc = JsonDocument.Parse(payloadBytes);
            var root = doc.RootElement;

            if (root.TryGetProperty("exp", out var expProp) && expProp.TryGetInt64(out var exp))
            {
                if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > exp) return null;
            }

            var claims = new List<Claim>();
            if (root.TryGetProperty("sub", out var sub))
                claims.Add(new Claim(ClaimTypes.NameIdentifier, sub.GetString() ?? string.Empty));
            if (root.TryGetProperty("email", out var email))
                claims.Add(new Claim(ClaimTypes.Email, email.GetString() ?? string.Empty));
            if (root.TryGetProperty("name", out var name))
                claims.Add(new Claim(ClaimTypes.Name, name.GetString() ?? string.Empty));
            if (root.TryGetProperty("partner_id", out var partnerId))
                claims.Add(new Claim("partner_id", partnerId.GetInt32().ToString()));

            var identity = new ClaimsIdentity(claims, "Bearer");
            return new ClaimsPrincipal(identity);
        }
        catch
        {
            return null;
        }
    }

    private static string Base64UrlEncode(byte[] input) =>
        Convert.ToBase64String(input).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] Base64UrlDecode(string input)
    {
        var output = input.Replace('-', '+').Replace('_', '/');
        switch (output.Length % 4)
        {
            case 2: output += "=="; break;
            case 3: output += "="; break;
        }
        return Convert.FromBase64String(output);
    }
}
