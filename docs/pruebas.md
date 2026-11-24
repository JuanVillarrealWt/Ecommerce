# Guía de pruebas y criterios de aceptación

Esta guía relaciona las funciones disponibles con verificaciones manuales y automatizadas. No se atribuyen resultados de ejecución: registra aquí la fecha, entorno y salida real de cada corrida.

## Matriz funcional

| Área | Criterio de aceptación | Verificación sugerida |
| --- | --- | --- |
| Catálogo y categorías | Productos, detalle, imágenes y filtro por categoría reflejan datos de Odoo. | Consultar `GET /api/products`, `/api/products/{id}`, `/api/products/{id}/image` y `/api/categories`; validar en Flutter. |
| Cuenta | Registro sincroniza el contacto; login entrega sesión; perfil solo modifica al cliente autenticado. | Probar datos válidos/inválidos y revisar asociación en Odoo. |
| Carrito | El carrito se mantiene asociado a la cuenta al volver a iniciar sesión. | Añadir, cambiar cantidad, quitar; consultar `GET/PUT /api/cart` y reiniciar API. |
| Checkout | Backend valida catálogo, cantidades, precio y cupón antes del pago. | Crear pago con carrito válido y probar cantidad/producto/cupón inválido. |
| Stripe | Éxito confirma la orden; fallo/cancelación no la marcan pagada; webhook verifica firma. | Usar Stripe CLI con los tres eventos configurados y revisar estados/historial. |
| Pedidos | Historial y detalle contienen solo pedidos propios confirmados. | Consultar `/api/orders` y `/api/orders/{id}` con dos cuentas; probar PDF y recepción. |
| Funciones de cliente | Favoritos, direcciones, notificaciones y reseñas persisten y se aíslan por cuenta. | Probar endpoints `/api/customer/features`; reseñar solo producto comprado en pedido confirmado. |

## Comandos de pruebas automatizadas

Desde la raíz del repositorio:

```powershell
dotnet test backend/ECommerce.Tests
```

Para Flutter:

```powershell
cd mobile
flutter test
```

Anota el resultado observado; las pruebas pueden variar conforme se actualiza el proyecto. No asumas el resultado de corridas anteriores como evidencia del estado actual.

## Prueba manual de integración

1. Inicia la API, Stripe CLI y Flutter con los pasos del [README](../README.md).
2. Confirma que catálogo y categorías cargan desde Odoo.
3. Registra una cuenta, inicia sesión, guarda dirección y agrega productos al carrito.
4. Completa un pago de prueba y confirma que el webhook actualiza el intento y la orden.
5. Revisa historial/detalle, PDF, estado de recepción, reseñas, favoritos y notificaciones.
6. Repite consultas autenticadas con otra cuenta para comprobar que no ve datos ajenos.

## Registro de ejecución

| Fecha | Entorno (Odoo/Android/Flutter/.NET) | Comando o flujo | Resultado observado | Evidencia |
| --- | --- | --- | --- | --- |
| Pendiente | Completar | Completar | Completar | Completar |

## Revisión estática de la colección Postman existente

Se contrastaron las solicitudes de `docs/Ecommerce_Postman_Collection.json` con los controladores y contratos actuales. Se corrigieron rutas obsoletas y se añadieron solicitudes para los flujos actuales. El JSON se pudo interpretar como una colección Postman v2.1; esto confirma su estructura, pero no demuestra conectividad con una instancia real.

### Solicitudes que coinciden con rutas actuales

- `GET /api/products`, `GET /api/products?categoryId=...`, `GET /api/products/{id}` y `GET /api/categories` siguen existiendo.
- `POST /api/auth/register` y `POST /api/auth/login` siguen existiendo.
- `GET /api/orders` y `GET /api/orders/{id}` siguen existiendo y requieren token.

### Hallazgos corregidos y límites actuales

1. **`GET /api/auth/me` no existe.** Se reemplazó por `GET /api/customer/features` para consultar la cuenta. La API ofrece `PUT /api/auth/profile` para actualizar el perfil.
2. **`POST /api/orders` está obsoleto.** La colección ahora ofrece `POST /api/checkout/payments`; el endpoint antiguo responde `410 Gone`.
3. **La colección no confirma pagos.** Iniciar checkout crea una cotización y un PaymentIntent de prueba. Confirmar el pago requiere el SDK Stripe y el webhook firmado; no se simula enviando manualmente un webhook desde Postman.
4. **Los IDs de ejemplo son fijos.** Categoría `1`, producto `1` y pedido `1` pueden no existir en tu base Odoo o pertenecer a otros datos. Sustitúyelos por IDs reales al ejecutar solicitudes.
5. **El token se obtiene al iniciar sesión.** Registro devuelve los datos del cliente. La solicitud Login guarda su token como `jwt_token` para las rutas autenticadas.
6. **Algunas solicitudes escriben datos.** Registro crea un cliente; iniciar checkout crea una cotización y un intento de pago de prueba. `GET /api/customer/features` puede refrescar estados observados de pedidos y generar una notificación si detecta un cambio. Revisa la descripción antes de enviar solicitudes.

La colección contiene solicitudes para catálogo, cuenta, carrito, checkout, pagos, pedidos y lecturas de funciones del cliente. Los IDs iniciales de `productId`, `categoryId` y `orderId` son ejemplos; cámbialos por valores presentes en tu Odoo. La colección no es parte de la compilación ni del arranque de Flutter o backend: el código no la carga como configuración. Un JSON mal formado afectaría su importación en Postman, no la app; enviar solicitudes sí puede crear los datos indicados arriba. El contrato vigente sigue siendo el código del backend y `api.md`.

## Pruebas unitarias y de integración

`dotnet test backend/ECommerce.Tests` y `flutter test` son los comandos indicados para las suites automatizadas. La matriz de arriba describe criterios a verificar, pero el registro permanece pendiente hasta ejecutar los comandos y guardar el resultado. Una prueba unitaria no sustituye las verificaciones externas de Odoo, Stripe CLI, red del dispositivo ni firma del webhook.

Para aislar fallos, registra también:

- Versión de .NET SDK, Flutter, Android y Postman usada en la ejecución.
- URL base/API usada, sin escribir secretos ni tokens en el registro.
- Si Odoo/Stripe estaban conectados y qué base/cuenta de prueba se utilizó.
- Método, ruta, código HTTP observado y resultado funcional, ocultando datos personales.
- Resultado de Flutter y logs backend relevantes, eliminando tokens, claves y datos sensibles antes de compartirlos.
