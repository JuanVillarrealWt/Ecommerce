$body = @'
{
  "jsonrpc": "2.0",
  "method": "call",
  "id": 1,
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
      {"fields": ["id","name","type","active","sale_ok"], "limit": 20}
    ]
  }
}
'@

$resp = Invoke-RestMethod -Uri 'http://localhost:8069/jsonrpc' -Method Post -ContentType 'application/json' -Body $body
$resp.result | ConvertTo-Json -Depth 5
