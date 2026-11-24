# E-commerce móvil con Flutter, ASP.NET Core, Odoo y Stripe

Aplicación de comercio electrónico con cliente Flutter, API REST ASP.NET Core y Odoo Community para catálogo y pedidos. Los pagos se procesan con Stripe PaymentIntents y webhooks firmados.

## Inicio rápido en tres pasos

Requisitos: .NET SDK 10, Flutter, Android Studio/emulador o dispositivo, Stripe CLI, acceso a Odoo y conectividad entre el móvil, la API y Stripe. Configura `.env` con datos locales de Odoo, `JWT_SECRET` aleatorio de al menos 64 caracteres y claves Stripe. No compartas `.env` ni claves secretas.

Abre tres terminales desde la raíz y deja activos los procesos:

### 1. API

```powershell
./scripts/run-api.ps1
```

Compila y ejecuta la API en el puerto `5000`, leyendo configuración de Odoo, JWT y Stripe desde `.env`.

### 2. Stripe CLI

```powershell
stripe listen --events "payment_intent.succeeded,payment_intent.payment_failed,payment_intent.canceled" --forward-to http://100.75.46.80:5000/api/checkout/webhook
```

Stripe CLI mostrará un secreto `whsec_...`. Guárdalo como `STRIPE_WEBHOOK_SECRET` en `.env` y reinicia la API. La IP `100.75.46.80` debe ser alcanzable desde Stripe CLI y desde el dispositivo.

### 3. Flutter

```powershell
cd mobile
flutter run --dart-define=API_BASE_URL=http://100.75.46.80:5000 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_51UeNlG41lvnNi0betl1jy8P8jB0BBcW7PsN0hbX3obPbmmzmkPekjCf5u3mA3UGX7fFd7kKf6gbVG6zrdlSPiWC700DRTDrSBp
```

La clave `pk_test_...` es publicable y de pruebas. `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `ODOO_API_KEY` y `JWT_SECRET` son solo del backend.

## Configuración local

1. Copia `.env.example` a `.env`.
2. Completa `ODOO_DB`, `ODOO_BASE_URL`, `ODOO_API_KEY`, `JWT_SECRET`, `STRIPE_SECRET_KEY` y `STRIPE_PUBLISHABLE_KEY`. La API acepta también `ODOO_DB_NAME`.
3. Inicia Stripe CLI, copia su valor `whsec_...` a `STRIPE_WEBHOOK_SECRET` y vuelve a iniciar la API.
4. Verifica que Odoo Community tenga Ventas habilitado, base inicializada y usuario técnico con API key.

El despliegue local de Odoo/PostgreSQL está descrito en `deployment/`. Cambia las contraseñas de demostración antes de levantarlo.

## Funcionalidades

- Catálogo Odoo, categorías, filtros y detalle de producto.
- Registro e inicio de sesión, con sincronización de clientes a Odoo.
- Carrito local y persistente por cuenta.
- Checkout con validación de precios, cupones y Stripe.
- Confirmación de pedidos en Odoo tras validar el webhook firmado.
- Historial/detalle de pedidos, estado de pago y comprobante PDF.
- Perfil, direcciones, favoritos, reseñas y notificaciones.

El backend guarda carritos, preferencias, intentos de pago y snapshots en archivos JSON locales. Consérvalos entre reinicios; este almacenamiento está pensado para desarrollo y no se comparte entre varias instancias.

## Documentación

- [Contrato de la API](docs/api.md)
- [Arquitectura](docs/arquitectura.md)
- [Plan de trabajo](docs/plan-trabajo.md)
- [Matriz de pruebas](docs/pruebas.md)

Documentación interactiva: `http://localhost:5000/doc` o `http://localhost:5000/swagger`.

## Requisitos y preparación detallada

Instala .NET SDK 10 y confirma que `dotnet --version` muestre una versión compatible con `net10.0`. Instala Flutter y Android Studio para disponer del SDK Android, emulador y herramientas de compilación. Para un teléfono físico, habilita depuración USB y verifica que el teléfono esté en una red que alcance la IP indicada en `API_BASE_URL`. Stripe CLI debe estar instalado y autenticado con la cuenta de pruebas correspondiente.

Odoo Community debe estar ejecutándose con una base creada, la aplicación Ventas instalada y productos disponibles. Crea un usuario técnico para la integración y una API key. La API usa ese acceso para consultar el catálogo, sincronizar clientes y gestionar cotizaciones/pedidos. No incluyas la API key en Flutter.

### Variables del archivo `.env`

El archivo `.env.example` es una plantilla; duplica el archivo como `.env` y completa los valores para tu entorno. El script de API reconoce `ODOO_DB` (o `ODOO_DB_NAME`), `ODOO_BASE_URL`, `ODOO_API_KEY`, `JWT_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` y `STRIPE_CURRENCY`. El script móvil lee `STRIPE_PUBLISHABLE_KEY`.

`JWT_SECRET` debe ser aleatorio y de al menos 64 caracteres, condición que valida `run-api.ps1`. Stripe separa la clave secreta del servidor (`sk_test_...` en pruebas) y la clave publicable del cliente (`pk_test_...`). El secreto webhook (`whsec_...`) es específico del listener Stripe CLI activo: si Stripe CLI genera otro secreto, actualiza `.env` y reinicia la API para que lo cargue.

### Orden de inicio y comprobaciones

1. Completa `.env` y asegúrate de que Odoo está accesible desde el equipo que ejecuta la API.
2. Inicia la API en la primera terminal. Espera a que termine la compilación y quede escuchando en el puerto 5000.
3. Inicia Stripe CLI en la segunda terminal. Conserva esa sesión abierta mientras pruebas pagos. El listener debe reenviar al mismo host/puerto de la API.
4. Inicia Flutter en la tercera terminal. La URL `API_BASE_URL` debe ser accesible desde el emulador/dispositivo; `localhost` en el teléfono representa al propio teléfono, no al computador.
5. Comprueba el catálogo y el inicio de sesión antes de probar pagos. Completa una compra de prueba y verifica el webhook y el estado del pedido en Odoo.

El flujo de tres pasos solicitado está configurado para `100.75.46.80`. Si esa dirección cambia o no es visible para el dispositivo, reemplázala tanto en `--forward-to` como en `API_BASE_URL`. En emuladores Android el host suele alcanzarse mediante `10.0.2.2`; en un teléfono físico usa una dirección de red alcanzable y revisa el firewall.

## Flujo principal de compra

La app carga productos y categorías desde la API. Al iniciar sesión, el backend asocia las operaciones con la cuenta autenticada. El carrito se puede sincronizar con la cuenta. Durante checkout, el backend valida los productos y precios consultando el catálogo actual, crea una cotización en Odoo e inicia un PaymentIntent en Stripe. El cliente confirma la operación usando el SDK Stripe; el backend utiliza el webhook firmado para procesar el resultado y confirmar en Odoo los pagos exitosos.

El cliente puede consultar estado e historial de pagos y pedidos. Las reseñas están asociadas a productos de pedidos confirmados; las direcciones se validan antes de guardarse y la dirección principal se sincroniza con el contacto de Odoo. Revisa [api.md](docs/api.md) para los contratos y restricciones de cada endpoint.

## Persistencia y datos locales

Odoo mantiene los datos principales de productos, contactos y ventas. El backend usa archivos JSON de desarrollo para información complementaria como carritos, preferencias, intentos de pago y snapshots. No borres esos archivos si necesitas mantener el estado entre reinicios. El proyecto está configurado para una instancia local; varias instancias del backend no comparten automáticamente esos archivos.

La base Postman utiliza algunos IDs fijos de ejemplo. Los IDs de producto, categoría y pedido dependen del contenido de la base Odoo; selecciona valores que existan en tu instalación antes de enviar esas solicitudes.

## Solución de problemas

| Síntoma | Revisar |
| --- | --- |
| API no inicia | `.env`, API key de Odoo, `JWT_SECRET` de 64 caracteres, claves Stripe, puerto 5000 y salida de `dotnet build`. |
| Flutter no conecta | `API_BASE_URL`, IP del equipo, firewall, red del dispositivo y que la API siga activa. |
| Catálogo vacío o error Odoo | URL/base/API key, permisos del usuario técnico, productos activos y conectividad Odoo JSON-2. |
| Stripe no actualiza el pedido | Listener Stripe CLI activo, `whsec_...` vigente en `.env`, reinicio de API después de cambiarlo y URL de reenvío correcta. |
| Dirección rechazada | Provincia válida, código postal de seis dígitos y celular ecuatoriano de diez dígitos que comience en `09`. |
| Carrito o estado cambió tras reinicio | Confirma que los archivos JSON locales no se hayan eliminado ni reemplazado. |

## Colección de Postman

La colección actualizada está en `docs/Ecommerce_Postman_Collection.json` y agrupa solicitudes manuales para catálogo, cuenta, carrito, checkout, pagos, pedidos y algunas lecturas de funciones del cliente. No se necesita para compilar o iniciar la aplicación y el código no la carga. Algunas solicitudes pueden crear datos de prueba; lee sus descripciones antes de enviarlas. Los IDs iniciales son ejemplos que deben existir en tu Odoo. Consulta el análisis en [pruebas.md](docs/pruebas.md); el contrato principal sigue siendo [api.md](docs/api.md) y los controladores del backend.
