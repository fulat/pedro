# Estado de implementación y decisiones de Pedro

Registro permanente del desarrollo. No implica implementar todas las tareas inmediatamente. Añadir decisiones breves en su categoría, sin duplicados.

`[x]` indica integración confirmada en el código de Pedro; `[ ]` indica trabajo pendiente o parcial. El soporte de Ubuntu/GNOME por sí solo no completa una tarea. Actualizar el estado al implementar y verificar cambios.

## Pedro Platform Requirements

### Security & Permissions

- [ ] **Keychain** — API Pedro para contraseñas, tokens, llaves y secretos mediante libsecret / GNOME Keyring.
- [ ] **XDG Portals** — integrar permisos y acceso seguro a recursos sensibles.
- [ ] **Camera & Microphone Permissions** — solicitudes de acceso y experiencia de consentimiento controlada por Pedro.
- [ ] **polkit Integration** — autorización de operaciones privilegiadas sin ejecutar Pedro completo como root.

### Notifications & Media

- [ ] **Notifications** — integración con Pedro y futuro Notification Center; los avisos locales de UI no constituyen un sistema de notificaciones.
- [ ] **Media Controls (MPRIS)** — detectar reproductores, Play/Pause/Next/Previous, metadata y activación de su aplicación.

### Screen Capture

- [ ] **Screenshot** — captura de pantalla de usuario mediante Wayland/GNOME. Las capturas de verificación de ventanas Qt no implementan esta capacidad.
- [ ] **Screen Recording** — XDG Portals + PipeWire.
- [ ] **Screen/Window Capture Permissions** — selección de monitor/ventana y consentimiento del usuario.

### Storage & Filesystem

- [ ] **Storage & Removable Devices (UDisks2)** — inventario de HDD, SSD, USB, particiones y volúmenes. Parcial: Este equipo enumera montajes GIO; falta integración completa de dispositivos.
- [ ] **Mount / Unmount / Eject** — acciones para montar, desmontar y expulsar volúmenes.
- [ ] **Mount / Volume Monitoring** — parcial: GVolumeMonitor actualiza Este equipo ante mount-added/removed/changed; faltan eventos de volúmenes y unidades sin montar.
- [ ] **General Hardware Detection** — unificar eventos de conexión/desconexión en PAPI; las integraciones específicas de Wi-Fi/Bluetooth no cubren hardware general.
- [x] **Filesystem Monitoring** — Desktop y Pedro Files usan GFileMonitor, agrupan eventos y actualizan el modelo incrementalmente, sin polling ni refrescos por frame. Files reemplaza el monitor al navegar; el monitoreo permanece invisible. Véanse [Desktop](desktop.md) y [Files](files.md).
- [ ] **Default Applications / MIME Associations** — Open With, aplicaciones predeterminadas y asociaciones MIME. La clasificación visual de archivos no implementa apertura con aplicaciones.
- [x] **Carpetas estándar mediante XDG** — Desktop y Files resuelven las carpetas del usuario activo mediante g_get_user_special_dir; la lógica vive en PAPI. El mismo código sirve en desarrollo y producción, sin rutas /home/<usuario> hardcodeadas.
- [ ] **Operaciones asíncronas completas** — parcial: enumeración, creación de carpetas/archivos y renombrado ya usan APIs asíncronas o workers. Faltan copiar, mover, comprimir, extraer y descargar con progreso, cancelación y errores; modelar jobs independientes cuando corresponda. Priorizar GLib/GIO y mantener interactiva la UI.

### Printers

- [ ] **Printers / CUPS** — detección, administración, impresión y gestión de colas.

### Power & Battery

- [ ] **UPower Integration** — batería, porcentaje, carga/descarga y dispositivos de energía.
- [ ] **Power Profiles** — consultar/cambiar Power Saver, Balanced y Performance cuando sea soportado mediante power-profiles-daemon, con UI propia de Settings. No implementar CPU governors ni políticas propias salvo necesidad futura específica.
- [ ] **Night Light** — GNOME/Mutter: On/Off, Sunset to Sunrise, horario manual y temperatura de color. Usar transformación de color del sistema para toda la pantalla, sin filtros visuales propios sobre ventanas.

La implementación de energía y Night Light debe ser la misma en Ubuntu development y en la ISO: `Pedro Settings → Pedro Power/Display Backend (PAPI) → GNOME / power-profiles-daemon / Mutter → Linux/hardware`.

### Location, Time & Region

- [ ] **GeoClue Integration** — ubicación para funciones que la requieran.
- [ ] **Timezone Integration** — detectar/configurar zona horaria automática o manualmente. Mostrar el reloj local no implementa configuración de zona horaria.
- [ ] **Locale & Region Settings** — parcial: idioma inglés/español dinámico mediante Qt y TOML; faltan UI regional y configuración de formatos de fecha/hora/región del sistema.

### System Configuration

- [ ] **GSettings / dconf Integration** — parcial: aplicaciones usan GSettings para favoritos y el script de apariencia configura GNOME; falta exponer configuración general del sistema mediante PAPI/Settings.
- [ ] **systemd-logind Integration** — sesiones/seats, suspensión, hibernación, reinicio, apagado y operaciones de login.
- [ ] **System Logs / Diagnostics** — acceso estructurado a systemd-journald; las estadísticas de sistema existentes no implementan consulta del journal.
- [ ] **Displays, resolución y escala** — backend y UI de Settings pendientes. Conservar las siguientes decisiones:

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

### Architecture Rule

Pedro debe ocultar las tecnologías internas al usuario final. La UI presenta conceptos Pedro: Passwords / Keychain, Notifications, Privacy, Storage, Printers, Battery, Energy, Displays, Default Apps, Location y Permissions.

Internamente puede usar libsecret, GNOME Keyring, XDG Portals, PipeWire, MPRIS, CUPS, UDisks2, udev, GSettings, GeoClue, polkit, UPower, power-profiles-daemon, Mutter, systemd-logind, GIO y journald. Encapsular estas capacidades detrás de PAPI o backends propios cuando corresponda; evitar dependencias directas de la UI en detalles de GNOME/Linux y sistemas paralelos.

## Desktop y menú del wallpaper

- [x] Crear carpetas y archivos vacíos con nombres únicos de forma asíncrona, con renombrado en línea.
- [x] Organización cuadrícula, libre y pilas expandibles por tipo; alineación y persistencia de preferencias y posiciones por modo.
- [x] Barreras de arrastre en Libre y Cuadrícula contra logo, menús, widgets y dock, con margen universal de 8 px también en Pila; Cuadrícula busca una celda válida cercana al soltar.
- [x] Gap de 8 px entre elementos en Cuadrícula y Pila, incluyendo áreas de selección; Libre permite superposición.
- [x] Arrastre visual en pilas: representación bajo el cursor, resaltado de destino y retorno sin modificar posiciones; permite arrastrar elementos de pilas expandidas.
- [ ] Conectar el drop a movimiento asíncrono de archivos/carpetas mediante PAPI, validando destinos, colisiones, errores y progreso. El gesto visual no mueve contenido.
- [ ] Conectar Pegar al portapapeles PAPI y mostrarlo únicamente con archivos compatibles.
- [ ] Conectar Seleccionar todo y orden por nombre/tipo/fecha/tamaño del menú del wallpaper; ampliar agrupación por nombre/fecha. El orden de Files no completa estas acciones del Desktop.
- [ ] Conectar Ajustes de pantalla a la capacidad Displays y la gestión de widgets a su UI; los menús existentes son presentación.
- [x] Sombra mínima de un píxel únicamente en los nombres del componente compartido de carpetas/archivos, para mejorar contraste sobre wallpapers claros.

## Pedro Files

- [x] Ventana Qt Quick desde dock/lateral, UI light/dark e inglés/español dividida en componentes.
- [x] Modelos PAPI e historial independientes por ventana; listados reales, Inicio y carpetas XDG, Este equipo mediante montajes GIO, Papelera mediante GVfs, Favoritos/Recientes mediante registros GTK. La Papelera se abre desde el dock.
- [x] Vistas cuadrícula, lista, columnas y mixta; orden por nombre, tipo (carpetas primero), tamaño y fecha mediante proxies Qt; scroll del cuerpo completo.
- [x] Componentes compartidos de carpeta/archivo con selección, doble clic y menú contextual; abrir una carpeta del Desktop presenta Files en su ruta real.
- [x] Menú del espacio vacío para creación asíncrona y propiedades de la carpeta actual; selección limpia al pulsar fuera; menus contextuales pueden sobresalir de la ventana.
- [x] Título alterna lateral completo/iconos, animación suave; controles de ventana y resize por bordes/esquinas.
- [ ] Ajustar ancho del lateral arrastrando la división.
- [ ] Conectar búsqueda, filtros, etiquetas y edición de marcadores; la presentación existe.
- [ ] Operaciones de archivos desde Files, incluida restauración/vaciado de Papelera; aplicar los jobs definidos en Storage & Filesystem.
- [ ] Integrar los backends GIO/GVfs necesarios en la futura sesión de producción.

Detalle: [Pedro Files](files.md).

## Idiomas, configuración y apariencia

- [x] Catálogos Qt inglés/español .ts/.qm, claves semánticas y JSON de referencia; selección dinámica de idioma en preferences.toml.
- [x] Preferencias globales de idioma, apariencia y wallpaper unificadas en secciones de preferences.toml; defaults en gui/config/ y overrides XDG del usuario en pedro/, con migración de ajustes anteriores.
- [x] Light/dark dinámicos, material Liquid por modo y wallpaper desde backend.wallpaper; zoom del dock configurable mediante [dock].hoverScale y expuesto a QML.
- [ ] UI de configuración del zoom del dock; conservar la fuente TOML existente.
- [ ] Selección de temas adicionales.
- [ ] Herramienta externa Node.js para generar catálogos desde metadatos y compilar .ts a .qm mediante Qt.
- [ ] Importar .qm externos con validación de claves y placeholders.

Mantener equivalencia de claves/placeholders en ambos idiomas. No introducir textos directamente en español ni configuración dentro de assets. Los .ts permanecen editables en desarrollo; distribuir .qm en producción, con artefactos generados bajo build/. Reservar TOML separados para dominios con responsabilidad propia.

Detalle: [idiomas y configuración](language.md).

## Aplicaciones y sesión

- [x] Activación desde el dock en Ubuntu/GNOME mediante PAPI y applications@pedro: Shell.App.activate_full() enfoca/restaura ventanas existentes o inicia la aplicación cerrada; indicadores basados en ventanas de GNOME.
- [ ] Menú explícito para abrir una nueva ventana.
- [ ] Distribuir la integración en la futura sesión GNOME de producción cuando se defina su boot/session flow. La integración actual del overlay no confirma el funcionamiento de la ISO.

La extensión requiere una nueva sesión tras instalarse. Mantener Ubuntu/GNOME como gestor de ventanas, sin gestión paralela; el clic normal no debe solicitar otra ventana.

Detalle: [integración GNOME](../gnome/application/readme.md).
