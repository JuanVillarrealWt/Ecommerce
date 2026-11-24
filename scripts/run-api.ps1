param(
    [string]$OdooBaseUrl = "http://localhost:8069",
    [string]$OdooDatabase = "ecommerce_limpio"
)

# Cargar variables de .env si existe
$envFile = Join-Path $PSScriptRoot "..\.env"
$apiKeyString = ""
$jwtSecret = ""
$stripeSecretKey = ""
$stripeWebhookSecret = ""
$stripeCurrency = "usd"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if (($k -eq "ODOO_DB" -or $k -eq "ODOO_DB_NAME") -and $v) { $OdooDatabase = $v }
            if ($k -eq "ODOO_BASE_URL" -and $v) { $OdooBaseUrl = $v }
            if ($k -eq "ODOO_API_KEY" -and $v) { $apiKeyString = $v }
            if ($k -eq "JWT_SECRET" -and $v) { $jwtSecret = $v }
            if ($k -eq "STRIPE_SECRET_KEY" -and $v) { $stripeSecretKey = $v }
            if ($k -eq "STRIPE_WEBHOOK_SECRET" -and $v) { $stripeWebhookSecret = $v }
            if ($k -eq "STRIPE_CURRENCY" -and $v) { $stripeCurrency = $v }
        }
    }
}

$ErrorActionPreference = "Stop"
if (-not $apiKeyString -and $env:ODOO_API_KEY) {
    $apiKeyString = $env:ODOO_API_KEY
}
if (-not $apiKeyString) {
    $apiKey = Read-Host "API key del usuario técnico de Odoo" -AsSecureString
    $apiKeyString = [System.Net.NetworkCredential]::new("", $apiKey).Password
}
if ($jwtSecret.Length -lt 64) {
    throw "Define JWT_SECRET con al menos 64 caracteres aleatorios en .env antes de iniciar la API."
}
if (-not $stripeSecretKey -and $env:STRIPE_SECRET_KEY) { $stripeSecretKey = $env:STRIPE_SECRET_KEY }
if (-not $stripeWebhookSecret -and $env:STRIPE_WEBHOOK_SECRET) { $stripeWebhookSecret = $env:STRIPE_WEBHOOK_SECRET }
if (-not $stripeSecretKey) {
    throw "Define STRIPE_SECRET_KEY en .env antes de iniciar la API."
}
if (-not $stripeWebhookSecret) {
    Write-Warning "Falta STRIPE_WEBHOOK_SECRET. Los pagos podrán iniciarse, pero el webhook no podrá verificar y confirmar los pedidos en Odoo."
}

$env:Odoo__BaseUrl = $OdooBaseUrl
$env:Odoo__Database = $OdooDatabase
$env:Odoo__ApiKey = $apiKeyString
$env:Jwt__Secret = $jwtSecret
$env:Stripe__SecretKey = $stripeSecretKey
$env:Stripe__WebhookSecret = $stripeWebhookSecret
$env:Stripe__Currency = $stripeCurrency

$existingListener = Get-NetTCPConnection -State Listen -LocalPort 5000 -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($existingListener) {
    $apiIsRunning = $false
    try {
        $probe = Invoke-WebRequest -Uri "http://127.0.0.1:5000/api/products" -TimeoutSec 4 -UseBasicParsing
        $apiIsRunning = $probe.StatusCode -eq 200
    }
    catch {
        $apiIsRunning = $false
    }

    if ($apiIsRunning) {
        Write-Host "La API ya está activa en http://127.0.0.1:5000. No es necesario abrir otra instancia."
        return
    }

    $owner = Get-Process -Id $existingListener.OwningProcess -ErrorAction SilentlyContinue
    $ownerName = if ($owner) { $owner.ProcessName } else { "proceso desconocido" }
    throw "El puerto 5000 ya está ocupado por $ownerName (PID $($existingListener.OwningProcess)). Cierra ese programa o libera el puerto antes de iniciar la API."
}

$project = Join-Path $PSScriptRoot "..\backend\ECommerce.WebApi\ECommerce.WebApi.csproj"
$webApiDll = Join-Path $PSScriptRoot "..\backend\ECommerce.WebApi\bin\Debug\net10.0\ECommerce.WebApi.dll"
$env:ASPNETCORE_ENVIRONMENT = "Development"

dotnet build $project -m:1
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo compilar la API."
}

Push-Location (Split-Path -Parent $project)
try {
    dotnet $webApiDll --urls "http://0.0.0.0:5000"
}
finally {
    Pop-Location
}
