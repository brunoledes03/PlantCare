# PlantCare — Bitácora de Cuidado de Plantas

PlantCare es una aplicación móvil para Android desarrollada con **Flutter y Dart**. Permite organizar plantas y mantener una bitácora de sus cuidados, con fotografías, observaciones y registro de riegos.

## ¿Qué problema resuelve?

Ayuda a recordar cuándo se regó cada planta y a conservar un historial de sus cuidados, sin depender de notas dispersas o de la memoria del usuario.

## Funcionalidades

- Registrar plantas con nombre, especie, fotografía y frecuencia de riego.
- Consultar la lista de plantas y abrir sus detalles con una transición **Hero**.
- Registrar riegos y consultar la fecha del último riego.
- Guardar observaciones en una bitácora individual por planta.
- Tomar fotografías con la cámara o seleccionarlas de la galería.
- Dictar observaciones con el micrófono y convertirlas en texto.
- Consultar los registros guardados después de cerrar y volver a abrir la aplicación.
- Eliminar plantas junto con su historial, previa confirmación.

## Tecnologías

- **Flutter y Dart:** interfaz y lógica de la aplicación.
- **SQLite (`sqflite`):** almacenamiento local de plantas y registros de cuidado.
- **`image_picker`:** acceso a cámara y galería.
- **`speech_to_text`:** reconocimiento de voz.
- **`path` y `path_provider`:** administración de rutas y archivos de fotografías.

## Estructura del código

- `lib/models/`: modelos `Plant` y `CareEntry`.
- `lib/data/`: acceso a SQLite mediante `PlantDatabase`.
- `lib/services/`: servicios de fotografías y reconocimiento de voz.
- `lib/screens/`: pantallas de lista, registro, detalle y observaciones.
- `lib/widgets/`: componentes visuales reutilizables.
- `lib/routes/`: rutas de navegación.
- `test/`: pruebas automatizadas de los modelos.

## Ejecución

Se necesita Flutter configurado y un dispositivo o emulador Android disponible.

```bash
flutter pub get
flutter run
```

Para ejecutar las pruebas y comprobar el código:

```bash
flutter analyze
flutter test
```

Para generar un APK de distribución:

```bash
flutter build apk --release
```

El APK resultante se genera en `build/app/outputs/flutter-apk/app-release.apk`.

## Contexto académico

Proyecto individual del **Parcial 2 de Programación de Dispositivos Móviles**. Su objetivo es demostrar navegación entre pantallas, persistencia local, manejo de errores e integración de cámara y micrófono en Android.
