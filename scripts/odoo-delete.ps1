$body = @'
{
  "jsonrpc": "2.0",
  "method": "call",
  "id": 2,
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": [
      "ecommerce_limpio",
      2,
      "43977d10d0dc083f831efc005b0529e9b6f8b3bc_oak",
      "product.template",
      "unlink",
      [[140, 141]],
      {}
    ]
  }
}
'@

$resp = Invoke-RestMethod -Uri 'http://localhost:8069/jsonrpc' -Method Post -ContentType 'application/json' -Body $body
$resp | ConvertTo-Json -Depth 5
