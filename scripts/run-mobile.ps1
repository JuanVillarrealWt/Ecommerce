param(
    [string]$ApiBaseUrl = "",
    [switch]$BuildApk
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "No existe .env en la raíz del proyecto."
}

$settings = @{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $parts = $line.Split("=", 2)
        $settings[$parts[0].Trim()] = $parts[1].Trim()
    }
}

$publishableKey = $settings["STRIPE_PUBLISHABLE_KEY"]
if (-not $publishableKey) {
    throw "Define STRIPE_PUBLISHABLE_KEY en .env."
}

if (-not $ApiBaseUrl) {
    $tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
    if (-not $tailscale) { throw "No se encontró Tailscale. Pasa -ApiBaseUrl http://IP_TAILSCALE:5000 manualmente." }
    $tailnetIp = (& tailscale ip -4 | Select-Object -First 1).Trim()
    if (-not $tailnetIp) { throw "Tailscale no devolvió una IP. Comprueba que esté conectado." }
    $ApiBaseUrl = "http://$($tailnetIp):5000"
}

$flutterArgs = @(
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=STRIPE_PUBLISHABLE_KEY=$publishableKey"
)

Push-Location (Join-Path $PSScriptRoot "..\mobile")
try {
    if ($BuildApk) {
        & flutter build apk --release @flutterArgs
    } else {
        & flutter run @flutterArgs
    }
    if ($LASTEXITCODE -ne 0) { throw "Flutter terminó con error ($LASTEXITCODE)." }
}
finally {
    Pop-Location
}
