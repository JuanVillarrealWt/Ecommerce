# Contrato HTTP Oficial de la API REST (ASP.NET Core)

La app móvil se comunica **exclusivamente** con estos endpoints. Nunca accede a las rutas JSON-2 de Odoo ni a la base de datos PostgreSQL de forma directa.

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
    "name": "Banda de resistencia",
    "description": "Set de 5 bandas",
    "price": 8.0,
    "imageUrl": "data:image/jpeg;base64,...",
    "categoryIds": [1],
    "stock": 25,
    "stockTracked": true
  }
]
```

### Detalle de producto
* **Método:** `GET`
* **Ruta:** `/api/products/{id}`
* **Respuesta 200 OK:** Objeto `ProductResponse` o `404 Not Found` si no existe en Odoo.

### Imagen de producto
* **Método:** `GET`
* **Ruta:** `/api/products/{id}/image`
* **Cabecera de respuesta:** `Cache-Control: public, max-age=86400`, `Content-Type: image/jpeg` o similar.
* **Respuesta 200 OK:** Flujo binario de la imagen o `404 Not Found`.

### Listar categorías
* **Método:** `GET`
* **Ruta:** `/api/categories`
* **Respuesta 200 OK:**
```json
[
  {
    "id": 1,
    "name": "Deportes",
    "parentId": null
  }
]
```

---

## 2. Autenticación y Perfil de Clientes

### Registro de cliente
* **Método:** `POST`
* **Ruta:** `/api/auth/register`
* **Cuerpo:**
```json
{
  "name": "Juan Pérez",
  "email": "juan@example.com",
  "password": "Password123!",
  "province": "Pichincha",
  "phone": "0991234567"
}
```
* **Reglas de validación:**
  - `province`: Debe ser una de las 24 provincias de Ecuador.
  - `phone`: Debe tener exactamente 10 dígitos y empezar con `09`.
  - El registro se sincroniza inmediatamente con Odoo creando o actualizando el contacto (`res.partner`). Si Odoo no responde, devuelve `503 Service Unavailable`.
* **Respuesta 200 OK:**
```json
{
  "id": 1,
  "name": "Juan Pérez",
  "email": "juan@example.com",
  "partnerId": 6,
  "province": "Pichincha",
  "phone": "0991234567"
}
```

### Inicio de sesión
* **Método:** `POST`
* **Ruta:** `/api/auth/login`
* **Cuerpo:**
```json
{
  "email": "juan@example.com",
  "password": "Password123!"
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
    "partnerId": 6,
    "province": "Pichincha",
    "phone": "0991234567"
  }
}
```

### Actualización de perfil
* **Método:** `PUT`
* **Ruta:** `/api/auth/profile`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Cuerpo:**
```json
{
  "name": "Juan Carlos Pérez",
  "province": "Tungurahua",
  "phone": "0987654321"
}
```
* **Respuesta 200 OK:** Datos actualizados del cliente en `CustomerDto`. Conserva snapshots de pedidos históricos y sincroniza cambios con Odoo.

---

## 3. Carrito Persistente (Requiere `Authorization: Bearer <token>`)

### Consultar carrito
* **Método:** `GET`
* **Ruta:** `/api/cart`
* **Respuesta 200 OK:**
```json
{
  "items": [
    {
      "productId": 7,
      "quantity": 2,
      "productName": "Banda de resistencia",
      "unitPrice": 8.0,
      "description": null,
      "imageUrl": null,
      "categoryIds": [1],
      "stock": 25
    }
  ]
}
```

### Reemplazar carrito
* **Método:** `PUT`
* **Ruta:** `/api/cart`
* **Cuerpo:** `{"items": [...]}` con la lista completa de artículos.
* **Respuesta 204 No Content**.

---

## 4. Checkout y Pagos con Stripe (Requiere `Authorization: Bearer <token>`)

### Iniciar checkout
* **Método:** `POST`
* **Ruta:** `/api/checkout/payments`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Cuerpo:**
```json
{
  "items": [
    { "productId": 7, "quantity": 1 },
    { "productId": 8, "quantity": 2 }
  ],
  "couponCode": "CUMBRES10",
  "savedAddressId": "3fa85f64-5717-4562-b3fc-2c963f66afa6"
}
```
* **Descripción:** Valida catálogo e inventario, aplica cupón si coincide, genera una cotización borrador en Odoo e inicia un `PaymentIntent` en Stripe.
* **Respuesta 201 Created:**
```json
{
  "attemptId": "attempt-guid",
  "clientSecret": "pi_..._secret_...",
  "customerId": "cus_...",
  "customerSessionClientSecret": "cuss_...",
  "orderName": "S00015",
  "amountTotal": 14.40,
  "currency": "usd"
}
```

### Preparar confirmación de pago
* **Método:** `POST`
* **Ruta:** `/api/checkout/payments/{attemptId}/confirmation`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:** `{"clientSecret": "pi_..._secret_..."}`

### Consultar estado de pago
* **Método:** `GET`
* **Ruta:** `/api/checkout/payments/{attemptId}`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:**
```json
{
  "id": "attempt-guid",
  "orderName": "S00015",
  "amountTotal": 14.40,
  "currency": "usd",
  "status": "paid"
}
```
*(Estados posibles: `creating`, `pending`, `paid`, `failed`, `canceled`).*

### Webhook de Stripe (Público / Firmado)
* **Método:** `POST`
* **Ruta:** `/api/checkout/webhook`
* **Cabecera:** `Stripe-Signature`
* **Descripción:** Verifica criptográficamente el payload con `STRIPE_WEBHOOK_SECRET`. Ante `payment_intent.succeeded`, confirma la orden en Odoo (`action_confirm`) y actualiza el intento a `paid`. Ante fallos o cancelaciones actualiza a `failed`/`canceled`.
* **Respuesta 200 OK**.

---

## 5. Pedidos (Requiere `Authorization: Bearer <token>`)

### Endpoint legado
* **Método:** `POST`
* **Ruta:** `/api/orders`
* **Respuesta 410 Gone:** Indica que los pedidos deben crearse obligatoriamente mediante el flujo de pago en `/api/checkout/payments`.

### Historial de pedidos
* **Método:** `GET`
* **Ruta:** `/api/orders`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:** Lista de `OrderResponse` del cliente con ventas confirmadas en Odoo (`sale` o `done`). Incluye bandera `received` si el usuario marcó la orden como recibida.

### Detalle de pedido
* **Método:** `GET`
* **Ruta:** `/api/orders/{id}`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:** Detalle de líneas, totales, estado y dirección de entrega. Si el pedido pertenece a otro cliente, devuelve `403 Forbidden`.

### Marcar pedido como recibido
* **Método:** `POST`
* **Ruta:** `/api/orders/{id}/received`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 204 No Content:** Marca el pedido en el registro del cliente como entregado exitosamente.

---

## 6. Historial de Pagos (Requiere `Authorization: Bearer <token>`)

* **Método:** `GET`
* **Ruta:** `/api/payments/history`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:**
```json
[
  {
    "orderId": 15,
    "orderName": "S00015",
    "amountTotal": 14.40,
    "currency": "usd",
    "createdAt": "2026-11-24T12:00:00Z",
    "status": "paid"
  }
]
```

---

## 7. Funcionalidades del Cliente (`/api/customer/features`)

### Cargar datos consolidados
* **Método:** `GET`
* **Ruta:** `/api/customer/features`
* **Cabecera:** `Authorization: Bearer <TOKEN>`
* **Respuesta 200 OK:**
```json
{
  "favoriteProductIds": [7, 8],
  "addresses": [
    {
      "id": "guid",
      "label": "Casa",
      "recipient": "Juan Pérez",
      "street": "Av. Amazonas N34-120",
      "city": "Quito",
      "province": "Pichincha",
      "postalCode": "170150",
      "phone": "0991234567",
      "isDefault": true
    }
  ],
  "notifications": [
    {
      "id": "guid",
      "type": "order",
      "title": "Actualización de S00015",
      "message": "El estado de tu pedido cambió a sale.",
      "orderId": 15,
      "createdAt": "2026-11-24T12:00:00Z",
      "isRead": false
    }
  ],
  "reviews": [],
  "purchasedProductIds": [7, 8]
}
```

### Favoritos
* **Añadir favorito:** `POST /api/customer/features/favorites/{productId}`
* **Quitar favorito:** `DELETE /api/customer/features/favorites/{productId}`
* **Respuestas:** `204 No Content`.

### Direcciones de envío
* **Crear dirección:** `POST /api/customer/features/addresses`
  - Valida provincia ecuatoriana, código postal de 6 dígitos, celular de 10 dígitos `09...`.
  - Si es la primera dirección o `isDefault: true`, se sincroniza automáticamente con el contacto en Odoo.
* **Editar dirección:** `PUT /api/customer/features/addresses/{id}`
* **Eliminar dirección:** `DELETE /api/customer/features/addresses/{id}`
  - Si la dirección es la predeterminada (`isDefault: true`), responde `409 Conflict` protegiendo la dirección principal.

### Notificaciones
* **Marcar como leída:** `POST /api/customer/features/notifications/{id}/read`
* **Respuesta:** `204 No Content`.

### Reseñas y Calificaciones
* **Crear o actualizar reseña:** `POST /api/customer/features/reviews`
  - **Cuerpo:** `{"productId": 7, "orderId": 15, "rating": 5, "comment": "Excelente calidad"}`
  - **Validación:** El cliente solo puede calificar productos que figuren en sus pedidos confirmados (`sale` o `done`).
* **Eliminar reseña:** `DELETE /api/customer/features/reviews/{productId}`
* **Listar reseñas públicas de un producto:** `GET /api/customer/features/products/{productId}/reviews` (Público / Sin token)
* **Obtener pedido apto para reseñar:** `GET /api/customer/features/products/{productId}/review-order` (Requiere Token)
