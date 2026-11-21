# ecommerce_mobile

## Conexión con la API

El emulador Android usa por defecto `http://10.0.2.2:5000`. Para probar en un
teléfono físico, conecta el teléfono y el computador a la misma red Wi‑Fi,
obtén la IPv4 del computador con `ipconfig` y ejecuta Flutter pasando esa IP:

```powershell
flutter run --dart-define=API_BASE_URL=http://IP_DE_TU_COMPUTADOR:5000
```

Por ejemplo, si `ipconfig` muestra `192.168.1.25`, usa
`--dart-define=API_BASE_URL=http://192.168.1.25:5000`. Inicia el backend con
`scripts/run-api.ps1`; este escucha en `0.0.0.0:5000`. Si Windows pregunta,
permite el acceso en redes privadas. La IP puede cambiar al reconectar el Wi‑Fi.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
