# Plan de Trabajo y Estado de la Solución

## Estado Actual de Módulos

| Módulo / Funcionalidad | Estado | Descripción |
| --- | :---: | --- |
| **Catálogo y Categorías** | Completado | Sincronización con Odoo JSON-2, buscador y filtrado por chips jerárquicos. |
| **Control de Existencias** | Completado | Validación de stock en Odoo, advertencia en UI e impedimento de sobrepedido. |
| **Autenticación y Clientes** | Completado | Registro con validaciones ecuatorianas, login JWT y sincronización con `res.partner` de Odoo. |
| **Carrito Persistente** | Completado | Carrito local y sincronización por cuenta en `account-carts.json`. |
| **Checkout y Cupones** | Completado | Validación de líneas, precios y cupones configurables en `appsettings.json`. |
| **Pagos con Stripe** | Completado | Flujo desacoplado con PaymentIntents y webhooks firmados con HMAC-SHA256 (`whsec_...`). |
| **Confirmación en Odoo** | Completado | La cotización borrador pasa a venta oficial (`sale`) al confirmarse el webhook. |
| **Gestión de Pedidos** | Completado | Historial, detalle completo, botón de marcar recibido y generación de comprobante PDF. |
| **Historial de Pagos** | Completado | Auditoría de transacciones y estados de pago en `/api/payments/history`. |
| **Direcciones de Envío** | Completado | Múltiples direcciones, validación estricta, dirección predeterminada sincronizada con Odoo y diálogos protegidos (`barrierDismissible: false`). |
| **Reseñas y Calificaciones** | Completado | Calificación de 1 a 5 estrellas con regla estricta de compra previa confirmada. Actualización reactiva instantánea. |
| **Favoritos y Notificaciones** | Completado | Lista de deseos y avisos automáticos ante cambios de estado en pedidos. |
| **Documentación y Guías** | Completado | Inicio rápido en 3 pasos, configuración con Tailscale, especificación de API, arquitectura y pruebas. |

---

## Preparación para Demostraciones y Despliegue

1. **Entorno local:**
   - Mantener Odoo, la API (`./scripts/run-api.ps1`) y Stripe CLI activos.
   - En caso de cambiar de máquina o reiniciar sesión de Stripe CLI, actualizar `STRIPE_WEBHOOK_SECRET` en `.env`.
   - Si se prueba desde un dispositivo móvil con Tailscale, verificar que ambos equipos estén en la misma red Tailscale y usar la IP asignada a la máquina anfitriona.
2. **Buenas prácticas para producción:**
   - Reemplazar los almacenes JSON locales (`customer-features.json`, `account-carts.json`, etc.) por una base de datos relacional compartida (ej. PostgreSQL o SQL Server).
   - Configurar HTTPS con certificados válidos y restringir CORS a los orígenes autorizados.
   - Gestionar secretos mediante Azure Key Vault, AWS Secrets Manager o variables de entorno protegidas.
