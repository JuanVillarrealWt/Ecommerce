# Contrato HTTP de la API

Flutter consume la API ASP.NET Core y no accede directamente a Odoo ni a PostgreSQL. Los endpoints de cuenta requieren `Authorization: Bearer <token>`. Base local: `http://localhost:5000`. Documentación interactiva: `/doc` o `/swagger`.

## Catálogo

| Método | Ruta | Uso |
| --- | --- | --- |
| GET | `/api/products` | Lista productos; acepta `?categoryId={id}`. |
| GET | `/api/products/{id}` | Detalle de producto. |
| GET | `/api/products/{id}/image` | Imagen de producto. |
| GET | `/api/categories` | Lista categorías. |

## Cuenta y carrito

| Método | Ruta | Auth | Uso |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | No | Registra cliente y sincroniza contacto con Odoo. |
| POST | `/api/auth/login` | No | Inicia sesión y devuelve token y cliente. |
| PUT | `/api/auth/profile` | Sí | Actualiza perfil. |
| GET/PUT | `/api/cart` | Sí | Consulta o reemplaza carrito persistido por cuenta. |

## Checkout y pagos

| Método | Ruta | Auth | Uso |
| --- | --- | --- | --- |
| POST | `/api/checkout/payments` | Sí | Valida productos y precios, crea cotización y PaymentIntent. Devuelve intento, `clientSecret`, orden, total y moneda. |
| POST | `/api/checkout/payments/{attemptId}/confirmation` | Sí | Registra/consulta confirmación iniciada por el cliente. |
| GET | `/api/checkout/payments/{attemptId}` | Sí | Consulta estado `creating`, `pending`, `paid`, `failed` o `canceled`. |
| POST | `/api/checkout/webhook` | Firma Stripe | Valida la firma; `payment_intent.succeeded` confirma la orden en Odoo. |
| GET | `/api/payments/history` | Sí | Historial de pagos del cliente. |

Para desarrollo, Stripe CLI reenvía `payment_intent.succeeded`, `payment_intent.payment_failed` y `payment_intent.canceled` al webhook. Backend: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` y `STRIPE_CURRENCY` (por defecto `usd`). Flutter: `STRIPE_PUBLISHABLE_KEY` y `API_BASE_URL` como `--dart-define`. No incluyas secretos en la app. Los cupones se configuran en `DiscountCoupons` con `Code`, `Percentage` y `ProductIds`.

## Pedidos

| Método | Ruta | Auth | Uso |
| --- | --- | --- | --- |
| GET | `/api/orders` | Sí | Lista pedidos confirmados propios. |
| GET | `/api/orders/{id}` | Sí | Detalle; impide acceso a pedidos ajenos. |
| POST | `/api/orders` | Sí | Endpoint legado: `410 Gone`; usa checkout. |
| POST | `/api/orders/{id}/received` | Sí | Registra recepción. |

El historial excluye cotizaciones pendientes y canceladas. Flutter genera el comprobante PDF desde el detalle.

## Funciones de cliente

Base `/api/customer/features`. Salvo reseñas públicas, requiere autenticación y opera sobre la cuenta actual.

| Método | Ruta | Uso |
| --- | --- | --- |
| GET | `/api/customer/features` | Preferencias, direcciones, notificaciones, compras y estados. |
| POST/DELETE | `/api/customer/features/favorites/{productId}` | Añade o quita favorito. |
| GET | `/api/customer/features/products/{productId}/review-order` | Busca compra elegible para reseñar. |
| GET | `/api/customer/features/products/{productId}/reviews` | Lista reseñas públicas. |
| POST | `/api/customer/features/reviews` | Publica o actualiza reseña de compra confirmada. |
| DELETE | `/api/customer/features/reviews/{productId}` | Elimina reseña propia. |
| POST | `/api/customer/features/addresses` | Guarda dirección y sincroniza la principal con Odoo. |
| PUT/DELETE | `/api/customer/features/addresses/{id}` | Edita o elimina dirección propia; la principal no se elimina. |
| POST | `/api/customer/features/notifications/{id}/read` | Marca notificación leída. |

Direcciones: provincia ecuatoriana, código postal de seis dígitos y celular de diez dígitos iniciado en `09`. Reseñas: calificación de 1 a 5 y comentario de hasta 1000 caracteres.

## Errores y persistencia

Los errores usan formato compatible con `ProblemDetails` y pueden responder `400`, `401`, `403`, `404`, `409`, `410` o `503`. Conserva los stores JSON entre reinicios; no son compartidos entre instancias.

## Ejemplos de solicitudes

### Crear un intento de pago

`POST /api/checkout/payments` requiere un token válido. El cuerpo envía identificadores y cantidades; el backend calcula los importes con datos actuales del catálogo. Puede incluir un cupón y el identificador de una dirección guardada del mismo usuario.

```json
{
  "items": [
    { "productId": 7, "quantity": 1 },
    { "productId": 8, "quantity": 2 }
  ],
  "couponCode": "CUMBRES10",
  "savedAddressId": "00000000-0000-0000-0000-000000000000"
}
```

La respuesta `201 Created` contiene `attemptId`, `clientSecret`, datos de Customer/Customer Session de Stripe cuando estén disponibles, `orderName`, `amountTotal` y `currency`. No registres ni compartas `clientSecret`: es una credencial efímera de esa operación de pago. Una dirección puede omitirse; si se envía, debe pertenecer a la cuenta autenticada.

### Reemplazar carrito de la cuenta

`PUT /api/cart` recibe `items`. Cada elemento conserva los datos de presentación del carrito; las cantidades deben estar entre 1 y 9999 y el máximo es 200 productos. El endpoint reemplaza el contenido guardado y responde `204 No Content`.

```json
{
  "items": [
    {
      "productId": 7,
      "quantity": 2,
      "productName": "Producto de ejemplo",
      "unitPrice": 10.0,
      "description": null,
      "imageUrl": null,
      "categoryIds": [],
      "stock": 10
    }
  ]
}
```

El precio guardado en el carrito es una representación para la interfaz, no una fuente confiable para el cobro: checkout vuelve a verificar los precios.

## Configuración del cliente HTTP

Al importar o duplicar solicitudes en Postman, configura `baseUrl` para apuntar al equipo que ejecuta la API. Emulador, teléfono y equipo pueden requerir direcciones distintas. En la colección de este repositorio, `POST /api/auth/login` guarda el token automáticamente en `jwt_token`; si haces una solicitud manual fuera de esa colección, copia el token de la respuesta y envíalo como `Authorization: Bearer <token>`. IDs de producto, pedido, dirección y categoría son propios de los datos actuales y no deben asumirse como universales.

No llames manualmente al webhook desde una solicitud normal para simular un pago: Stripe CLI entrega el cuerpo y firma correspondientes. Usa el endpoint de checkout y deja que el proveedor emita eventos. La API acepta únicamente eventos con firma válida.

## Orden sugerido de validación

1. Comprueba `GET /api/products` y `GET /api/categories` sin token.
2. Registra una cuenta válida o inicia sesión con una cuenta existente.
3. Usa el token devuelto para probar perfil, carrito y funciones de cliente.
4. Crea un intento de checkout y confirma el pago con la app/SDK Stripe de prueba.
5. Comprueba el listener de Stripe, consulta `/api/checkout/payments/{attemptId}`, `/api/payments/history` y `/api/orders`.

Este orden ayuda a distinguir errores de conectividad y configuración de Odoo de errores de autenticación o procesamiento de pagos.
