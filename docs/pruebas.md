# Guía de Pruebas y Criterios de Aceptación

Esta guía relaciona todas las funciones de la plataforma móvil y el backend con criterios de aceptación concretos y verificaciones manuales y automatizadas.

---

## Matriz Funcional de Pruebas

| Módulo | Criterio de Aceptación | Verificación Sugerida |
| --- | --- | --- |
| **Catálogo y Categorías** | Productos, descripciones, stock e imágenes reflejan Odoo en tiempo real. Filtro por categoría y búsqueda funcionan. | Consultar `GET /api/products`, `GET /api/products?categoryId=...` y `GET /api/categories`. Probar búsqueda en la app móvil. |
| **Inventario y Existencias** | Si el stock es 0, el botón de compra se deshabilita. No se puede pedir más del stock existente. | Intentar ingresar una cantidad superior al stock en `ProductDetailPage`. Verificar mensajes de advertencia. |
| **Cuenta y Perfil** | Registro valida provincia de Ecuador y celular `09...`. Sincroniza contacto con Odoo. Login devuelve JWT. | Probar registro con datos válidos e inválidos. Validar creación del `res.partner` en Odoo. Actualizar perfil en `PUT /api/auth/profile`. |
| **Carrito Persistente** | El carrito se conserva al cerrar y volver a abrir sesión, o entre dispositivos distintos. | Agregar productos, reiniciar app, cerrar e iniciar sesión con la misma cuenta. Verificar `GET /api/cart`. |
| **Checkout y Cupones** | El backend valida precios de Odoo, stock y aplica cupón solo si coincide con los productos válidos. | Enviar solicitud con cupón `CUMBRES10`. Comprobar cálculo del total y creación del intento en Stripe. |
| **Stripe y Webhook** | El pago exitoso confirma la orden en Odoo. El fallo o cancelación la deja pendiente o cancelada. Firma HMAC verificada. | Usar tarjetas de prueba de Stripe con Stripe CLI activo. Comprobar recepción en `/api/checkout/webhook` y estado final en Odoo (`sale`). |
| **Historial y Comprobante PDF** | Pedidos confirmados aparecen en la lista. Se genera comprobante PDF sin errores en el dispositivo. | Abrir `OrdersPage`, seleccionar pedido, verificar detalle y presionar botón de descargar/ver comprobante PDF. |
| **Confirmación de Entrega** | El usuario puede marcar su pedido como recibido. El estado se refleja en la app. | Pulsar botón "Marcar como recibido" en `OrderDetailPage`. Verificar cambio de icono y persistencia. |
| **Direcciones de Envío** | Múltiples direcciones guardadas. La predeterminada sincroniza con Odoo. No se puede borrar la predeterminada. | Crear, editar y borrar direcciones. Validar que la ventana de confirmación no se cierre al tocar afuera (`barrierDismissible: false`). |
| **Favoritos** | Agregar o quitar favorito actualiza inmediatamente la UI sin recargar manualmente. | Presionar corazón en catálogo o detalle. Comprobar que en "Mis preferencias" se actualiza al instante. |
| **Reseñas Verificadas** | Solo se puede calificar productos comprados en pedidos confirmados (`sale`/`done`). | Intentar calificar un producto no comprado (debe bloquearse). Calificar uno comprado, editar y borrar reseña. Verificar actualización inmediata. |

---

## Comandos de Pruebas Automatizadas

### Backend (.NET 10)
Desde la raíz del repositorio:
```powershell
dotnet test backend/ECommerce.Tests
```

### Aplicación Móvil (Flutter)
Desde la carpeta `mobile`:
```powershell
cd mobile
flutter test
```

---

## Verificación Manual de Integración de Extremo a Extremo

1. **Levantar el entorno:**
   - Iniciar la API con `./scripts/run-api.ps1`.
   - Iniciar Stripe CLI con:
     `stripe listen --events "payment_intent.succeeded,payment_intent.payment_failed,payment_intent.canceled" --forward-to http://100.75.46.80:5000/api/checkout/webhook`
   - Iniciar Flutter con:
     `flutter run --dart-define=API_BASE_URL=http://100.75.46.80:5000 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
2. **Crear usuario y dirección:**
   - Registrar una cuenta nueva (ej. `test@example.com`, provincia `Pichincha`, celular `0991234567`).
   - Guardar una dirección en "Mis preferencias". Comprobar que no se cierra si se toca fuera del diálogo.
3. **Flujo de compra:**
   - Seleccionar un producto con existencias, añadir al carrito e ir a checkout.
   - Pagar usando una tarjeta de prueba de Stripe (ej. `4242 4242 4242 4242`, fecha futura, CVC cualquier 3 dígitos).
   - Verificar en la consola de Stripe CLI que el evento `payment_intent.succeeded` fue recibido y respondió `200 OK`.
4. **Verificación post-compra:**
   - Comprobar que el pedido aparece en "Mis pedidos" como confirmado (`sale`).
   - Generar el PDF del comprobante y verificar la orden.
   - Marcar el pedido como recibido.
   - Ir a la ficha del producto comprado y verificar que ahora aparece el botón para calificarlo.
   - Enviar una reseña y verificar que se muestra de inmediato.
   - Eliminar la reseña y verificar que desaparece de inmediato sin tener que salir y volver a entrar.
