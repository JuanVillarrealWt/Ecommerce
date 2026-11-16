# E-commerce móvil integrado con Odoo

Proyecto integrador de Aplicaciones Móviles. Arquitectura prevista: Flutter → ASP.NET Core Web API → Odoo Community JSON-2 → PostgreSQL.

## Requisitos locales

- .NET SDK 10 (la plantilla del entorno disponible creó proyectos `net10.0`).
- Flutter SDK y Android Studio/emulador.
- Docker Desktop con Compose.
- Odoo 20 Community, que puede iniciarse con el Compose de `deployment/`.

## Odoo con Docker

1. Copia `.env.example` a `.env` y cambia las contraseñas de demostración.
2. Ejecuta `docker compose -f deployment/docker-compose.yml up -d`.
3. Abre `http://localhost:8069`, crea la base de datos indicada por `ODOO_DB` y activa Ventas.
4. En Odoo crea un usuario técnico para integración, genera una API key y guárdala localmente; no la agregues a Git ni a la app móvil.
5. Confirma en `http://localhost:8069/doc` el método `product.product/search_read` y sus campos para la instalación concreta.

## Configuración de la API

Desde PowerShell, ejecuta `./scripts/run-api.ps1`. El script solicita la API key en una entrada segura y configura `Odoo__BaseUrl`, `Odoo__Database` y `Odoo__ApiKey` solo para ese proceso. No guardes la API key en `appsettings.json`.

Inicia la API con `dotnet run --project backend/ECommerce.WebApi --launch-profile http`. El perfil publica HTTP en el puerto 5000 para el emulador local; limita este uso a una red de desarrollo controlada.

La aplicación Android Emulator usa por defecto `http://10.0.2.2:5000` para llegar al host. Si el backend usa otro puerto, pásalo con `--dart-define=API_BASE_URL=http://10.0.2.2:PUERTO`. En un teléfono físico usa la IP local del equipo y un entorno HTTPS apropiado.

## Estado

El primer corte conecta el catálogo móvil con endpoints de productos de la API, cuyo adaptador está preparado para JSON-2. La validación real requiere que el equipo configure su Odoo y su API key. El resto de requisitos y el estado exacto se mantienen en `docs/arquitectura.md` y `docs/plan-trabajo.md`.
