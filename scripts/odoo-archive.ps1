# Archivar (desactivar) los productos Standard delivery (140) y Donation (141)
$body = @'
{
  "jsonrpc": "2.0",
  "method": "call",
  "id": 3,
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": [
      "ecommerce_limpio",
      2,
      "43977d10d0dc083f831efc005b0529e9b6f8b3bc_oak",
      "product.template",
      "write",
      [[140, 141], {"active": false, "sale_ok": false}],
      {}
    ]
  }
}
'@

$resp = Invoke-RestMethod -Uri 'http://localhost:8069/jsonrpc' -Method Post -ContentType 'application/json' -Body $body
Write-Host "Resultado write:" ($resp | ConvertTo-Json -Depth 3)

# Verificar que ya no aparecen en búsqueda activa
$verify = @'
{
  "jsonrpc": "2.0",
  "method": "call",
  "id": 4,
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": [
      "ecommerce_limpio",
      2,
      "43977d10d0dc083f831efc005b0529e9b6f8b3bc_oak",
      "product.template",
      "search_read",
      [["|", ["name","ilike","delivery"], ["name","ilike","donation"]]],
      {"fields": ["id","name","active"], "limit": 10}
    ]
  }
}
'@

$resp2 = Invoke-RestMethod -Uri 'http://localhost:8069/jsonrpc' -Method Post -ContentType 'application/json' -Body $verify
Write-Host "Verificacion (productos activos con esos nombres):" ($resp2.result | ConvertTo-Json -Depth 3)
