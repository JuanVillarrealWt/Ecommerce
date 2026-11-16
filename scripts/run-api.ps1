param(
    [string]$OdooBaseUrl = "http://localhost:8069",
    [string]$OdooDatabase = "odoo_ecommerce"
)

$ErrorActionPreference = "Stop"
$apiKey = Read-Host "API key del usuario técnico de Odoo" -AsSecureString
$env:Odoo__BaseUrl = $OdooBaseUrl
$env:Odoo__Database = $OdooDatabase
$env:Odoo__ApiKey = [System.Net.NetworkCredential]::new("", $apiKey).Password

dotnet run --project (Join-Path $PSScriptRoot "..\backend\ECommerce.WebApi") --launch-profile http
