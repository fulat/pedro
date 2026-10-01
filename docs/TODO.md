# Decisiones y trabajo pendiente

Registro permanente de decisiones de diseño, mejoras arquitectónicas y funcionalidades definidas para el desarrollo de Pedro.

Este documento no implica implementar inmediatamente todo lo listado. Su propósito es preservar decisiones importantes para retomarlas cuando corresponda. Añadir elementos breves, claros y organizados, revisando los existentes para evitar duplicados.

### Operaciones asíncronas

- Pedro debe evitar bloquear el hilo principal de la interfaz siempre que exista una alternativa asíncrona razonable.
- Operaciones potencialmente lentas como copiar, mover, comprimir, extraer o descargar archivos deben ejecutarse de forma asíncrona y mostrar progreso en la interfaz.
- Para operaciones de archivos, priorizar APIs existentes del sistema como GLib/GIO antes de implementar infraestructura propia.
- La UI debe permanecer interactiva mientras estas operaciones se ejecutan.
- Cuando sea necesario, modelar las operaciones largas como jobs independientes con estado, progreso, cancelación y manejo de errores.

### Monitoreo del filesystem

Las vistas de archivos de Pedro deben mantenerse sincronizadas mediante eventos del sistema, no mediante polling periódico ni refrescos por frame.

Usar preferentemente GLib/GIO (`GFileMonitor`) para observar cambios en directorios.

- El escritorio debe mantener un monitor sobre la carpeta Desktop durante la sesión.
- Pedro Files debe mantener un monitor sobre la carpeta actualmente abierta.
- Al cambiar de carpeta, reemplazar el monitor correspondiente.
- Los eventos deben actualizar únicamente los elementos afectados cuando sea posible.
- Si llegan muchos cambios juntos, agruparlos antes de actualizar la UI para evitar renders innecesarios.
- El monitoreo debe permanecer invisible para el usuario; no mostrar “Refreshing” salvo que exista una operación excepcionalmente costosa.

Estado: Desktop y Pedro Files enumeran de forma asíncrona y usan `GFileMonitor` con actualizaciones incrementales y agrupación de eventos. Pedro Files reemplaza el monitor al navegar y reconcilia snapshots por URI.

### Carpetas estándar del usuario mediante XDG

- Resolver Desktop y las demás carpetas estándar mediante las APIs XDG del usuario activo, preferentemente GLib (`g_get_user_special_dir`). Nunca hardcodear rutas como `/home/<usuario>/Desktop`.
- Usar el mismo código en development sobre Ubuntu y en la ISO final; no separar la resolución de rutas según el modo de ejecución.
- Mantener la resolución y las operaciones del filesystem en PAPI/backend. QML debe representar los elementos del modelo.

Estado: implementado para Desktop. Véase [arquitectura del Desktop](desktop.md).

### Acciones del menú del wallpaper

Implementado: creación asíncrona de carpetas y archivos vacíos con nombres únicos y renombrado en línea; modos cuadrícula, libre y pilas expandibles por tipo; control de alineación y persistencia de preferencias y posiciones.

Pendiente: conectar ajustes de pantalla y gestión de widgets; implementar las opciones adicionales de agrupación por nombre y fecha y conectar los selectores de agrupación del menú. Las operaciones de archivos deben seguir en PAPI y utilizar APIs existentes del sistema.

### Drag and drop de archivos en pilas

Implementado: gesto visual de arrastre en pila, con una representación que sigue al cursor, resaltado de carpetas de destino y retorno al origen al soltar o cancelar, sin modificar la disposición ni las posiciones guardadas. Expandir una pila permite arrastrar sus elementos individuales.

Pendiente: conectar el drop a operaciones asíncronas de PAPI para mover archivos y carpetas a un directorio de destino, con validación de destinos, colisiones, errores y progreso. El gesto visual actual no mueve contenido en el filesystem.

### Display, resolución y escala

Estado: decisión arquitectónica pendiente de implementación.

Pedro debe utilizar la infraestructura existente de Linux/GNOME/Mutter para detectar y configurar los displays, sin implementar detección de monitores ni modos de video desde cero.

- Obtener desde Mutter/GNOME las capacidades reales de cada display: resolución actual, nativa/preferida y resoluciones soportadas; refresh rates soportados; escala actual y escalas permitidas; tamaño físico y DPI aproximado cuando estén disponibles.
- Pedro Settings debe presentar esta información mediante su propia UI, con un backend de display en PAPI que delegue la configuración real a Mutter/GNOME.
- No hardcodear resoluciones ni escalas, ni introducir lógica especial para Parallels, development mode, una VM concreta o un fabricante de monitor. El frontend y la lógica principal deben ser los mismos para displays virtuales y monitores físicos.
- Priorizar normalmente la resolución nativa/preferida y utilizar scaling para controlar el tamaño visual de la UI, en lugar de reducir la resolución para agrandar los elementos.
- Permitir escalas como 100%, 125%, 150%, 175% y 200% únicamente cuando estén soportadas por la configuración gráfica correspondiente; los valores deben provenir de las capacidades reportadas.
- Mostrar una opción `Recommended` para resolución y escala, tratándolas como recomendaciones independientes.
- Inicialmente, respetar la configuración/recomendación que GNOME/Mutter considere adecuada cuando exista, sin reemplazar inmediatamente su criterio.
- Más adelante, Pedro puede implementar una política propia conservadora para recomendar escala según densidad/DPI, siempre utilizando las capacidades reales reportadas por Mutter.

Arquitectura esperada:

```text
Pedro Settings → Pedro Display Backend (PAPI) → GNOME/Mutter → Linux graphics stack → Display
```

Durante development:

```text
Pedro → Mutter → Parallels virtual display
```

En production:

```text
Pedro → Mutter → GPU/DRM/KMS → physical display
```

### Idiomas y configuración centralizada

Implementado: inglés y español mediante catálogos Qt `.ts`/`.qm`, claves semánticas y JSON de referencia; selección dinámica en `[language]` de `preferences.toml`. Configuración TOML centralizada con defaults en `gui/config/` y overrides XDG del usuario en `pedro/`. Véase [idiomas y configuración](language.md).

Pendiente: herramienta independiente en Node.js para generar catálogos a partir de metadatos y compilar `.ts` a `.qm` mediante las herramientas de Qt; permitir que Pedro importe esos `.qm` externos ya compilados, validando compatibilidad de claves y placeholders. Durante desarrollo, mantener los `.ts` editables; distribuir `.qm` en producción. Los `.qm` generados por el build permanecen en `build/`, no en el source. Implementado: selección dinámica light/dark en `[appearance]` de `preferences.toml`, material liquid por modo y wallpaper correspondiente. Pendiente: selección de temas adicionales. Mantener claves y placeholders equivalentes en ambos idiomas; no volver a introducir textos de UI directamente en español ni configuraciones dentro de los assets.

Decisión: unificar preferencias globales relacionadas (idioma, apariencia/theme y wallpaper) en `preferences.toml`, usando secciones TOML. Reservar archivos separados para dominios con responsabilidad propia; preservar ajustes existentes mediante migración.

Pendiente: conectar la UI de preferencias al zoom del dock. El factor ya es configurable dinámicamente mediante `[dock].hoverScale` en `preferences.toml` y está expuesto a QML; no introducir una segunda fuente de configuración.

### Menú del wallpaper

Pendiente: conectar «Pegar» al portapapeles mediante PAPI y mostrarlo únicamente cuando haya archivos compatibles; implementar selección de todos los elementos, orden por nombre/tipo/fecha/tamaño y acceso a widgets. La presentación está preparada; conservar las acciones existentes de creación y organización sin duplicar la lógica del modelo.

### Pedro Files

Implementado: ventana Qt Quick desde el dock y navegación lateral, con UI light/dark e inglés/español dividida en componentes. Cada ventana mantiene un controlador y modelo independientes de PAPI, historial atrás/adelante, listados reales y vistas de cuadrícula, lista, columnas y mixta, sin panel lateral de detalles. Inicio y carpetas estándar usan XDG; Este equipo utiliza montajes GIO; Papelera utiliza GVfs; Favoritos y Recientes consumen los registros compartidos de GTK. Véase [Pedro Files](files.md).

Implementado: orden por nombre, tipo, tamaño y fecha mediante proxies del modelo PAPI.

Pendiente: ajustar el ancho de la navegación lateral mediante arrastre de su división, con posibilidad de reducirla a iconos; búsqueda, filtros, etiquetas, edición de marcadores, apertura de archivos con aplicaciones y operaciones asíncronas de archivos en esta ventana, incluyendo restaurar/vaciar Papelera. Integrar los backends GIO/GVfs requeridos en la futura sesión de producción; no crear sistemas paralelos de filesystem o montaje.

### Activación de aplicaciones desde el dock

Implementado para el overlay Ubuntu/GNOME: PAPI activa mediante la integración `applications@pedro`, que delega en `Shell.App.activate()`; el clic enfoca/restaura ventanas existentes o abre la aplicación cuando está cerrada. GNOME aporta los indicadores basados en ventanas. La extensión requiere una nueva sesión tras instalarse. Véase [integración GNOME](../gnome/application/readme.md).

Pendiente: menú explícito de nueva ventana y distribución de esta integración dentro de la futura sesión GNOME de producción, cuando se defina ese boot/session flow. No convertir los clics normales en solicitudes de nueva ventana ni implementar gestión de ventanas paralela.
