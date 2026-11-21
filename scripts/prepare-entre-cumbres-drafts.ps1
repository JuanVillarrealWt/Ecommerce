param(
    [string]$OdooBaseUrl = "http://localhost:8069",
    [string]$OdooDatabase = "ecommerce_limpio"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"
$apiKey = $env:ODOO_API_KEY
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*ODOO_API_KEY\s*=\s*(.+?)\s*$') { $apiKey = $Matches[1] }
        if ($line -match '^\s*ODOO_BASE_URL\s*=\s*(.+?)\s*$') { $OdooBaseUrl = $Matches[1] }
        if ($line -match '^\s*ODOO_DB\s*=\s*(.+?)\s*$') { $OdooDatabase = $Matches[1] }
    }
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $secureKey = Read-Host "API key del usuario técnico de Odoo" -AsSecureString
    $apiKey = [System.Net.NetworkCredential]::new("", $secureKey).Password
}

$catalog = @(Get-Content (Join-Path $PSScriptRoot "entre-cumbres-catalogo-demo.json") -Raw | ConvertFrom-Json)
function Get-OdooScalar($Value) {
    while ($Value -is [array]) {
        if ($Value.Count -eq 0) { return $null }
        $Value = $Value[0]
    }
    return $Value
}
function Invoke-OdooJson2([string]$Model, [string]$Method, [hashtable]$Body) {
    $headers = @{ Authorization = "Bearer $apiKey"; "X-Odoo-Database" = $OdooDatabase }
    $uri = "$($OdooBaseUrl.TrimEnd('/'))/json/2/$Model/$Method"
    $response = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 15 -Compress)
    $result = $response.Content | ConvertFrom-Json -NoEnumerate
    if ($result -is [array]) {
        foreach ($row in $result) { $row }
    } else {
        $result
    }
}

Write-Host "Conectando a Odoo y actualizando el catálogo ENTRE CUMBRES..."
$categoryNames = @($catalog.category | Sort-Object -Unique)
$categoryIds = @{}
foreach ($categoryName in $categoryNames) {
    $domain = ,([object[]]@("name", "=", $categoryName))
    $found = @(Invoke-OdooJson2 "product.category" "search_read" @{ domain = $domain; fields = @("id", "name"); limit = 1 })
    if ($found.Count -gt 0) {
        $categoryIds[$categoryName] = [int]$found[0].id
    } else {
        $createdIds = @(Invoke-OdooJson2 "product.category" "create" @{ vals_list = @(@{ name = $categoryName }) })
        while ($createdIds.Count -eq 1 -and $createdIds[0] -is [array]) { $createdIds = @($createdIds[0]) }
        $categoryIds[$categoryName] = [int]$createdIds[0]
    }
}

$categoryIdList = @($categoryIds.Values | ForEach-Object { [int]$_ })
$catalogDomain = ,([object[]]@("categ_id", "in", $categoryIdList)) + ,([object[]]@("active", "=", $true))
$existingProducts = @(Invoke-OdooJson2 "product.template" "search_read" @{ domain = $catalogDomain; fields = @("id", "name", "categ_id", "sale_ok", "active", "list_price", "description_sale", "description", "is_storable"); limit = 500 })
$duplicateIds = @($existingProducts | Group-Object { "$($_.categ_id[0])|$($_.name)" } | ForEach-Object { $_.Group | Sort-Object { [int]$_.id } | Select-Object -Skip 1 | ForEach-Object { [int]$_.id } })
if ($duplicateIds.Count -gt 0) {
    [void](Invoke-OdooJson2 "product.template" "write" @{ ids = $duplicateIds; vals = @{ active = $false; sale_ok = $false } })
    Write-Host "Copias repetidas archivadas: $($duplicateIds.Count)."
}
$existingProducts = @(Invoke-OdooJson2 "product.template" "search_read" @{ domain = $catalogDomain; fields = @("id", "name", "categ_id", "sale_ok", "active", "list_price", "description_sale", "description", "is_storable"); limit = 500 })
$productIdsByKey = @{}
$existingByKey = @{}
foreach ($existingProduct in $existingProducts) {
    $categoryId = [int]$existingProduct.categ_id[0]
    $productId = [int]$existingProduct.id
    $key = "$categoryId|$($existingProduct.name)"
    $productIdsByKey[$key] = $productId
    $existingByKey[$key] = $existingProduct
}

$newProductValues = [System.Collections.Generic.List[object]]::new()
$metadataByKey = @{}
foreach ($item in $catalog) {
    $key = "$($categoryIds[$item.category])|$($item.name)"
    $metadataByKey[$key] = $item
    $values = @{
        name = [string]$item.name
        categ_id = [int]$categoryIds[$item.category]
        list_price = [decimal]$item.price
        description_sale = [string]$item.description
        description = "Catálogo de demostración ENTRE CUMBRES. Stock inicial generado solo para pruebas; confirmar inventario físico y precio antes de operar ventas reales."
        sale_ok = $true
        active = $true
        is_storable = $true
    }
    if ($productIdsByKey.ContainsKey($key)) {
        $current = $existingByKey[$key]
        $needsUpdate = [decimal]$current.list_price -ne [decimal]$item.price -or
            $current.description_sale -ne [string]$item.description -or
            $current.description -ne [string]$values.description -or
            $current.sale_ok -ne $true -or $current.active -ne $true -or $current.is_storable -ne $true
        if ($needsUpdate) {
            $id = [int]$productIdsByKey[$key]
            [void](Invoke-OdooJson2 "product.template" "write" @{ ids = @($id); vals = $values })
        }
    } else {
        $newProductValues.Add($values)
    }
}

$createdCount = 0
if ($newProductValues.Count -gt 0) {
    [void](Invoke-OdooJson2 "product.template" "create" @{ vals_list = @($newProductValues.ToArray()) })
    $createdCount = $newProductValues.Count
}

$products = @(Invoke-OdooJson2 "product.template" "search_read" @{ domain = $catalogDomain; fields = @("id", "name", "categ_id", "sale_ok", "list_price"); limit = 500 })
$activeByKey = @{}
foreach ($product in $products) {
    $key = "$([int]$product.categ_id[0])|$($product.name)"
    if ($metadataByKey.ContainsKey($key)) { $activeByKey[$key] = $product }
}
if ($activeByKey.Count -ne $catalog.Count) {
    $sample = if ($products.Count -gt 0) { "Primero: $($products[0].name), categoría=$($products[0].categ_id | ConvertTo-Json -Compress), id=$($products[0].id | ConvertTo-Json -Compress)." } else { "Odoo no devolvió productos." }
    $knownKey = @($metadataByKey.Keys | Select-Object -First 1)
    throw "Se esperaban $($catalog.Count) productos activos; Odoo devolvió $($products.Count) fichas y se mapearon $($activeByKey.Count). $sample Clave esperada: $knownKey. No se ajustó el stock."
}

$locations = @(Invoke-OdooJson2 "stock.location" "search_read" @{ domain = ,([object[]]@("usage", "=", "internal")); fields = @("id", "name", "complete_name"); limit = 200 })
$stockLocation = $locations | Where-Object { $_.complete_name -eq "WH/Stock" -or $_.complete_name -match "/(Stock|Existencias)$" } | Select-Object -First 1
if (-not $stockLocation) { $stockLocation = $locations | Where-Object { $_.name -eq "Stock" -or $_.name -eq "Existencias" } | Select-Object -First 1 }
if (-not $stockLocation) { throw "No encontré una ubicación interna de inventario en Odoo; no se ajustó stock." }

$productIdList = @($activeByKey.Values | ForEach-Object { [int]$_.id })
$quantDomain = ,([object[]]@("product_id", "in", $productIdList)) + ,([object[]]@("location_id", "=", [int]$stockLocation.id))
$existingQuants = @(Invoke-OdooJson2 "stock.quant" "search_read" @{ domain = $quantDomain; fields = @("product_id", "quantity"); limit = 500 })
$quantityByProduct = @{}
foreach ($quant in $existingQuants) {
    $quantityByProduct[[int]$quant.product_id[0]] = [decimal]$quant.quantity
}

$inventoryLines = [System.Collections.Generic.List[object]]::new()
foreach ($item in $catalog) {
    $key = "$($categoryIds[$item.category])|$($item.name)"
    $productId = [int]$activeByKey[$key].id
    $hasStock = $quantityByProduct.ContainsKey($productId) -and $quantityByProduct[$productId] -gt 0
    if ($hasStock) { continue }

    switch ([string]$item.size) {
        "small" { $initialQuantity = Get-Random -Minimum 200 -Maximum 501 }
        "medium" { $initialQuantity = Get-Random -Minimum 100 -Maximum 221 }
        "large" { $initialQuantity = Get-Random -Minimum 50 -Maximum 101 }
        default { throw "Tamaño de inventario no definido para $($item.name)." }
    }
    $inventoryLines.Add(@{
        product_id = $productId
        location_id = [int]$stockLocation.id
        inventory_quantity = $initialQuantity
        inventory_quantity_set = $true
    })
}

if ($inventoryLines.Count -gt 0) {
    [void](Invoke-OdooJson2 "stock.quant" "create" @{
        context = @{ inventory_mode = $true }
        vals_list = @($inventoryLines.ToArray())
    })
}

$pendingQuants = @(Invoke-OdooJson2 "stock.quant" "search_read" @{
    domain = ,([object[]]@("location_id", "=", [int]$stockLocation.id)) + ,([object[]]@("inventory_quantity_set", "=", $true))
    fields = @("id", "inventory_quantity", "quantity")
    limit = 500
})
$pendingIds = @($pendingQuants | Where-Object { [decimal]$_.inventory_quantity -ne [decimal]$_.quantity } | ForEach-Object { [int]$_.id })
if ($pendingIds.Count -gt 0) {
    [void](Invoke-OdooJson2 "stock.quant" "action_apply_inventory" @{ ids = $pendingIds; context = @{ inventory_mode = $true } })
}

$verification = @(Invoke-OdooJson2 "product.product" "search_read" @{
    domain = ,([object[]]@("product_tmpl_id", "in", @($activeByKey.Values | ForEach-Object { [int]$_.id })))
    fields = @("id", "name", "list_price", "free_qty", "sale_ok", "categ_id")
    limit = 500
})
$verified = @($verification | Where-Object { $_.sale_ok -eq $true -and [decimal]$_.list_price -gt 0 -and [decimal]$_.free_qty -gt 0 })
if ($verified.Count -lt $catalog.Count) {
    throw "Odoo dejó $($verified.Count) de $($catalog.Count) productos con precio, venta habilitada y stock positivo. Revisa el resultado antes de probar compras."
}

Write-Host "Catálogo activo verificado: $($verified.Count) productos en $($categoryNames.Count) categorías."
Write-Host "Nuevos productos creados: $createdCount. Ubicación: $($stockLocation.complete_name)."
Write-Host "Stock demo aplicado solo a los productos que aún no tenían unidades; no se reemplazó stock previo."
foreach ($categoryName in $categoryNames) {
    $categoryId = [int]$categoryIds[$categoryName]
    $categoryProducts = @($verified | Where-Object { [int]$_.categ_id[0] -eq $categoryId })
    Write-Host "- $categoryName`: $($categoryProducts.Count) productos activos"
}
Write-Host "Inventario demostrativo: pequeño 200–500, mediano 100–220, voluminoso 50–100 unidades. Verifica conteos y precios antes de vender realmente."
