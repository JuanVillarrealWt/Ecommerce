# Contrato HTTP Oficial de la API REST (ASP.NET Core)

La app móvil se comunica **únicamente** con estos endpoints. Nunca accede a las rutas JSON-2 de Odoo ni a PostgreSQL.

---

## 1. Catálogo y Categorías

### Listar productos
* **Método:** `GET`
* **Ruta:** `/api/products`
* **Parámetros de consulta (opcional):** `?categoryId={id}`
* **Respuesta 200 OK:**
```json
[
  {
    "id": 7,
    "name": "PROD-TEST-001",
    "description": "Producto de prueba 1",
    "price": 10.0,
    "imageUrl": "data:image/jpeg;base64,...",
    "categoryIds": [1]
  }
]
```

### Detalle de producto
* **Método:** `GET`
* **Ruta:** `/api/products/{id}`
* **Respuesta 200 OK:** Objeto `ProductResponse` o `404 Not Found` si no existe en Odoo.

### Listar categorías
* **Método:** `GET`
* **Ruta:** `/api/categories`
* **Respuesta 200 OK:**
```json
[
  {
    "id": 1,
    "name": "Electrónica",
    "parentId": null
  }
]
```

---

## 2. Autenticación de Clientes

### Registro de cliente
* **Método:** `POST`
* **Ruta:** `/api/auth/register`
* **Cuerpo:**
```json
{
  "name": "Juan Pérez",
  "email": "juan@example.com",
  "password": "password123"
}
```
* **Respuesta 200 OK:**
```json
{
  "id": 1,
  "name": "Juan Pérez",
  "email": "juan@example.com",
  "partnerId": 6
}
```

### Inicio de sesión
* **Método:** `POST`
* **Ruta:** `/api/auth/login`
* **Cuerpo:**
```json
{
  "email": "juan@example.com",
  "password": "password123"
}
```
* **Respuesta 200 OK:**
```json
{
  "token": "eyJhbGciOi...",
  "customer": {
    "id": 1,
    "name": "Juan Pérez",
    "email": "juan@example.com",
    "partnerId": 6
  }
}
```

---

## 3. Pedidos (Requiere `Authorization: Bearer <token>`)

### Crear y confirmar pedido
* **Método:** `POST`
* **Ruta:** `/api/orders`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Cuerpo:**
```json
{
  "items": [
    { "productId": 7, "quantity": 1 },
    { "productId": 8, "quantity": 2 }
  ]
}
```
* **Respuesta 201 Created:**
```json
{
  "id": 1,
  "name": "S00001",
  "partnerId": 6,
  "partnerName": "Juan Pérez",
  "state": "sale",
  "amountTotal": 40.0,
  "createdAt": "2026-11-15T20:30:00Z",
  "items": [
    {
      "productId": 7,
      "productName": "PROD-TEST-001",
      "quantity": 1,
      "unitPrice": 10.0,
      "subtotal": 10.0
    },
    {
      "productId": 8,
      "productName": "PROD-TEST-002",
      "quantity": 2,
      "unitPrice": 2,
      "subtotal": 30.0
    }
  ]
}
```

### Historial de pedidos del cliente
* **Método:** `GET`
* **Ruta:** `/api/orders`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:** Lista de `OrderResponse` pertenecientes al cliente autenticado.

### Detalle de pedido
* **Método:** `GET`
* **Ruta:** `/api/orders/{id}`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:** Detalle del pedido.
* **Respuesta 403 Forbidden:** Si el pedido pertenece a otro cliente (RN-04).
