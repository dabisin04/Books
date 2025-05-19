# Books - Aplicación de Gestión de Libros

## Descripción
Books es una aplicación móvil desarrollada en Flutter que permite a los usuarios gestionar su biblioteca personal, realizar análisis de texto y mantener un registro de sus lecturas.

## Tecnologías Principales
- **Framework**: Flutter (SDK ^3.0.0)
- **Arquitectura**: Clean Architecture con BLoC Pattern
- **Base de Datos**: SQLite (sqflite)
- **Estado**: flutter_bloc
- **UI**: Material Design
- **Procesamiento de Texto**: flutter_quill, markdown
- **IA**: Google Generative AI
- **Almacenamiento Local**: shared_preferences
- **Networking**: http, connectivity_plus

## Estructura del Proyecto
```
lib/
├── application/     # Lógica de aplicación y casos de uso
├── domain/         # Entidades y reglas de negocio
├── infrastructure/ # Implementaciones concretas
├── presentation/   # UI y widgets
├── services/       # Servicios externos
└── main.dart       # Punto de entrada
```

## Entidades Principales
1. **Libro**
   - Título
   - Autor
   - Descripción
   - Calificación
   - Estado de lectura
   - Fecha de inicio/fin

2. **Nota**
   - Contenido
   - Fecha
   - Libro asociado
   - Análisis de texto

## Flujo de Trabajo
1. **Inicio de la Aplicación**
   - Inicialización de servicios
   - Carga de configuración
   - Verificación de conectividad

2. **Gestión de Libros**
   - Creación de nuevo libro
   - Edición de información
   - Registro de progreso
   - Calificación y reseñas

3. **Análisis de Texto**
   - Integración con Google AI
   - Procesamiento de notas
   - Generación de resúmenes

4. **Sincronización**
   - Almacenamiento local
   - Backup de datos
   - Sincronización con servicios externos

## Endpoints y Pruebas

### API Local (SQLite)
1. **Libros**
   - `GET /books` - Listar todos los libros
   - `POST /books` - Crear nuevo libro
   - `PUT /books/{id}` - Actualizar libro
   - `DELETE /books/{id}` - Eliminar libro

2. **Notas**
   - `GET /books/{id}/notes` - Obtener notas de un libro
   - `POST /books/{id}/notes` - Crear nueva nota
   - `PUT /notes/{id}` - Actualizar nota
   - `DELETE /notes/{id}` - Eliminar nota

### Pruebas
1. **Pruebas Unitarias**
   ```bash
   flutter test
   ```

2. **Pruebas de Integración**
   ```bash
   flutter test integration_test
   ```

3. **Pruebas Manuales**
   - Instalar la aplicación
   - Crear un nuevo libro
   - Agregar notas
   - Probar análisis de texto
   - Verificar sincronización

## Configuración del Entorno
1. Clonar el repositorio
2. Instalar dependencias:
   ```bash
   flutter pub get
   ```
3. Configurar variables de entorno en `.env`
4. Ejecutar la aplicación:
   ```bash
   flutter run
   ```

## Características Adicionales
- Análisis de texto con IA
- Sistema de calificaciones
- Transiciones de página personalizadas
- Soporte para markdown
- Gestión de conectividad
- Iconos personalizados

## Contribución
1. Fork el repositorio
2. Crear una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Crear un Pull Request

## Licencia
Este proyecto está bajo la Licencia MIT.

## Getting Started

A few resources to get you started if this is your first Flutter project:

- https://flutter.dev/docs/get-started/codelab
- https://flutter.dev/docs/cookbook

For help getting started with Flutter, view our
https://flutter.dev/docs, which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Getting Started: FlutLab - Flutter Online IDE

- How to use FlutLab? Please, view our https://flutlab.io/docs
- Join the discussion and conversation on https://flutlab.io/residents
