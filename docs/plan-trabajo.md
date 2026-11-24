# Estado y siguientes pasos

## Alcance implementado

- Integración Flutter → API ASP.NET Core → Odoo para catálogo, categorías, clientes y pedidos.
- Registro/inicio de sesión, perfil y carrito asociado a la cuenta.
- Checkout con precios validados en backend, cupones opcionales, Stripe PaymentIntent y confirmación de pedidos mediante webhook firmado.
- Historial/detalle de pedidos, estado e historial de pagos, comprobante PDF.
- Preferencias de cliente: favoritos, reseñas, notificaciones y direcciones guardadas.
- Scripts locales para API y Flutter; guía de inicio en tres terminales en el README.

## Preparación para ejecutar

1. Configurar `.env` local con Odoo, secreto JWT y claves Stripe; no versionar valores privados.
2. Confirmar acceso a Odoo, base de datos configurada, usuario técnico y productos/categorías disponibles.
3. Ejecutar API, Stripe CLI y Flutter siguiendo el [inicio rápido](../README.md).
4. Verificar conectividad desde el dispositivo a la URL definida en `API_BASE_URL` y recepción del webhook en `/api/checkout/webhook`.

## Pendientes de validación por entorno

- Probar el flujo completo con una instalación Odoo configurada y datos reales del equipo.
- Validar pagos de prueba de Stripe, eventos exitosos/fallidos/cancelados y reintentos del webhook.
- Ejecutar las pruebas disponibles en el entorno local y registrar resultados actualizados en `pruebas.md`.
- Antes de desplegar, sustituir stores JSON locales por persistencia compartida y durable si se ejecutarán varias instancias; revisar HTTPS, CORS, red y gestión de secretos.

Los IDs de productos y pedidos dependen de cada base Odoo; no reutilices IDs de una base demostrativa como valores universales.

## Mapa del flujo funcional

El catálogo inicia en Odoo y se expone mediante productos y categorías de la API. La app consume esa información para navegación, detalle y carrito. La cuenta permite asociar carrito, direcciones y preferencias al cliente autenticado. Al confirmar compra, la API vuelve a validar las líneas y los precios; luego coordina la cotización de Odoo con el intento Stripe. Solo el webhook verificado permite tratar el evento de pago como resultado confirmado en el ERP.

Después de la compra, la aplicación presenta el historial, detalle, estado y comprobante. Las funciones adicionales de cuenta permiten mantener favoritos, notificaciones, direcciones y reseñas vinculadas a compras confirmadas. Los endpoints actuales están descritos en [api.md](api.md), mientras que [arquitectura.md](arquitectura.md) explica las responsabilidades de los componentes.

## Lista de preparación antes de una demostración

- Tener `.env` local completo, excluido del control de versiones, y comprobar que `.env.example` no contiene credenciales reales.
- Mantener en ejecución Odoo, la API y Stripe CLI durante la demostración.
- Verificar que los productos, categorías y cliente de prueba existen en la base Odoo que se está utilizando.
- Actualizar el secreto webhook si Stripe CLI crea un `whsec_...` distinto; reiniciar la API para cargar el cambio.
- Confirmar que IP/puerto usados por Stripe CLI y Flutter son accesibles desde sus respectivos procesos.
- Preparar tarjetas de prueba oficiales de Stripe en el entorno de pruebas, sin registrar datos de tarjeta reales en capturas o documentos.
- Revisar archivos JSON persistentes y no borrarlos durante una sesión que dependa de carritos, pedidos o intentos existentes.
- Guardar evidencia de los flujos exitosos y también de errores esperados, como token ausente, artículo no disponible y webhook inválido.

## Evolución recomendada

El siguiente trabajo de ingeniería debería centrarse en validación de extremo a extremo con Odoo y Stripe de prueba, cobertura automatizada de reglas y documentación sincronizada con endpoints. Antes de usar el sistema fuera del entorno local, conviene reemplazar el almacenamiento auxiliar JSON por una base durable compartida, desplegar bajo HTTPS, restringir CORS y revisar la gestión/rotación de secretos. Estas son tareas de preparación de despliegue; no son necesarias para ejecutar el flujo local descrito en el README.
