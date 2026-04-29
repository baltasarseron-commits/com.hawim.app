# Blueprint de la Aplicación

## Visión General

Esta aplicación es un sistema de gestión para ingenieros, que incluye autenticación de usuarios y una interfaz para visualizar datos relevantes.

## Características y Diseño Implementados

*   **Autenticación de Usuarios:**
    *   Registro e inicio de sesión mediante correo electrónico y PIN (contraseña).
    *   Funcionalidad para recuperar el PIN a través del correo electrónico.
    *   La sesión del usuario persiste gracias a `FirebaseAuth.instance.authStateChanges()`.

*   **Estructura del Proyecto:**
    *   El punto de entrada es `lib/main.dart`.
    *   La lógica de negocio para la autenticación y gestión de datos de ingenieros está encapsulada en `lib/engineer_service.dart`.
    *   Las pantallas de la interfaz de usuario están separadas en sus propios archivos (`lib/login_screen.dart`, `lib/main_screen.dart`).

*   **Diseño y Tema:**
    *   Se utiliza Material 3 (`useMaterial3: true`).
    *   El esquema de color se genera a partir de un color semilla (`Colors.deepPurple`).
    *   Se utilizan fuentes personalizadas de `google_fonts` (Oswald, Roboto, Open Sans) para una tipografía consistente y moderna.
    *   Los componentes como `AppBar`, `ElevatedButton` y `InputDecoration` tienen un estilo centralizado en `ThemeData`.

*   **Gestión de Estado:**
    *   Se utiliza el paquete `provider` para la inyección de dependencias (`EngineerService`) y la gestión del estado de la autenticación.

## Plan para el Próximo Cambio

_(Esta sección se actualizará con cada nueva solicitud de cambio.)_
