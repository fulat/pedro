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

- [x] **Output Volume** — slider conectado a PAPI mediante WirePlumber wpctl; eventos PipeWire mantienen sincronizada la salida predeterminada, incluidos cambios externos. Operaciones asíncronas y escrituras agrupadas; mover el slider desactiva mute. Pulsar la bocina alterna mute con icono específico y conserva el volumen anterior. Requiere wpctl y pw-dump en la sesión.

- [ ] **Calendar** — la fecha abre un panel independiente; implementar el calendario en ese panel.
- [ ] **Notifications** — integración con Pedro y futuro Notification Center; los avisos locales de UI no constituyen un sistema de notificaciones. La campana independiente de la barra superior abre su propio panel; conectar este panel al sistema de notificaciones.
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
- [x] **Carpetas estándar mediante XDG** — Desktop y Files resuelven las carpetas del usuario activo mediante g_get_user_special_dir; la lógica vive en PAPI. El mismo código sirve en desarrollo y producción, sin rutas /home/<usuario> hardcodeadas.
- [ ] **Operaciones asíncronas completas** — parcial: enumeración, creación de carpetas/archivos y renombrado ya usan APIs asíncronas o workers. Copiar/cortar/pegar y arrastrar comparten un gestor GIO cancelable, con progreso del archivo actual y errores parciales. Faltan comprimir, extraer y descargar, además de una cola de jobs simultáneos; modelar jobs independientes cuando corresponda. Priorizar GLib/GIO y mantener interactiva la UI.

### Printers

- [ ] **Printers / CUPS** — detección, administración, impresión y gestión de colas.

### Power & Battery

- [x] **Screen Brightness** — slider conectado a PAPI y GNOME SettingsDaemon Power por D-Bus asíncrono; escucha PropertiesChanged para cambios del teclado, agrupa escrituras y se desactiva si el sistema no expone control de brillo. Verificado con servicio D-Bus de prueba; el display virtual actual no permite validar brillo físico.

- [ ] **UPower Integration** — parcial: barra superior representa el nivel con relleno proporcional y lee presencia, porcentaje y WarningLevel del DisplayDevice mediante D-Bus asíncrono y eventos. El relleno interno cambia a rojo en batería baja/crítica según UPower; porcentaje e icono abren un panel independiente de batería, cuyo contenido queda pendiente. Faltan estado de carga/descarga, dispositivos de energía y UI completa.
- [ ] **Power Profiles** — consultar/cambiar Power Saver, Balanced y Performance cuando sea soportado mediante power-profiles-daemon, con UI propia de Settings. No implementar CPU governors ni políticas propias salvo necesidad futura específica. Coordinar el perfil con gaming y restaurar el estado anterior cuando corresponda.
- [ ] **Night Light** — GNOME/Mutter: On/Off, Sunset to Sunrise, horario manual y temperatura de color. Usar transformación de color del sistema para toda la pantalla, sin filtros visuales propios sobre ventanas.

La implementación de energía y Night Light debe ser la misma en Ubuntu development y en la ISO: `Pedro Settings → Pedro Power/Display Backend (PAPI) → GNOME / power-profiles-daemon / Mutter → Linux/hardware`.

### Location, Time & Region

- [ ] **GeoClue Integration** — ubicación para funciones que la requieran.
- [ ] **Timezone Integration** — detectar/configurar zona horaria automática o manualmente. Mostrar el reloj local no implementa configuración de zona horaria.
- [ ] **Locale & Region Settings** — parcial: idioma inglés/español dinámico mediante Qt y TOML; faltan UI regional y configuración de formatos de fecha/hora/región del sistema.

### System Configuration

- [ ] **Network Connection UI** — parcial: PAPI detecta la conexión principal de NetworkManager por D-Bus/eventos y distingue Wi-Fi, Ethernet, otras redes y ausencia de conexión. La barra abre Wi-Fi o una vista de red con nombre real; Wi-Fi sin adaptador no se puede activar. Ventana Network Settings reutiliza el frame Qt Quick, con vistas Wi-Fi, Ethernet, VPN, Proxy, Advanced y Diagnostics, en inglés/español. Switch Wi-Fi y estado/redes disponibles son reales; formularios avanzados, VPN/Proxy y diagnósticos están en vista previa con aplicación desactivada. El popup Ethernet muestra IP real (IPv4 o IPv6 de NetworkManager), oculta por defecto con un ojo para revelarla. Faltan escritura de perfiles, conexión/olvido de redes, velocidad Ethernet, VPN/Proxy y pruebas de conectividad. Véase [Network Settings](network.md).

- [ ] **GSettings / dconf Integration** — parcial: aplicaciones usan GSettings para favoritos y el script de apariencia configura GNOME; falta exponer configuración general del sistema mediante PAPI/Settings.
- [ ] **systemd-logind Integration** — sesiones/seats, suspensión, hibernación, reinicio, apagado y operaciones de login.
- [ ] **System Logs / Diagnostics** — acceso estructurado a systemd-journald; las estadísticas de sistema existentes no implementan consulta del journal.
- [ ] **Displays, resolución y escala** — backend y UI de Settings pendientes. Conservar las siguientes decisiones:

Pedro debe utilizar la infraestructura existente de Linux/GNOME/Mutter para detectar y configurar los displays, sin implementar detección de monitores ni modos de video desde cero.

- Obtener desde Mutter/GNOME las capacidades reales de cada display: resolución actual, nativa/preferida y resoluciones soportadas; refresh rates soportados, incluidos modos de alta frecuencia cuando el monitor los ofrezca; escala actual y escalas permitidas; tamaño físico y DPI aproximado cuando estén disponibles.
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

## Pedro User Experience & System Capabilities

### High Priority / Core Experience

- [ ] **Accessibility** — integrar accesibilidad del sistema utilizando la infraestructura existente de Linux/GNOME, incluyendo screen reader, navegación por teclado, zoom, high contrast, sticky keys, slow keys y otras funciones compatibles. Pedro debe proveer su propia UI, sin reinventar AT-SPI/Orca.

- [ ] **Fingerprint / Biometrics** — integrar autenticación biométrica cuando el hardware sea compatible, reutilizando `libfprint` / `fprintd` y la infraestructura de autenticación existente del sistema.

- [ ] **Clipboard History** — crear una experiencia nativa de Pedro para consultar elementos copiados recientemente, incluyendo texto, imágenes, links y otros tipos compatibles. Debe evitar almacenar contenido sensible cuando corresponda.

- [ ] **Drag & Drop Between Applications** — parcial: File/Folder inicia el arrastre nativo Qt con `text/uri-list`; un receptor de ubicación compartido mueve archivos mediante PAPI/GIO en el fondo del Desktop, Files y columnas. El componente conserva el gesto dentro de vistas con scroll y QDrag muestra una captura translúcida del archivo junto al cursor. Verificados el inicio del gesto, las transferencias y el feedback visible con entrada real de Mutter/Wayland (archivo/carpeta hacia Desktop y carpeta dentro de carpeta), incluyendo commit del icono posterior a start_drag; falta comprobar interoperabilidad con aplicaciones externas GTK/Wayland, portales y la futura sesión de producción.

- [ ] **Share Sheet** — parcial: los menús de archivos/carpetas presentan Share, sin backend de transferencia. Crear una experiencia centralizada de `Share...` donde una aplicación pueda enviar contenido a otras aplicaciones o acciones compatibles sin implementar su propio menú de compartir.

- [ ] **Unified Open / Save Dialogs** — proveer un File Picker consistente para `Open`, `Save`, `Save As`, uploads y selección de archivos utilizando XDG FileChooser/Portals cuando corresponda.

- [ ] **Application Permissions Dashboard** — crear una vista centralizada de privacidad/permisos donde el usuario pueda revisar y controlar acceso a Camera, Microphone, Location, Screen Capture, Notifications, Files/Folders y otras capacidades sensibles.

- [ ] **Background Applications Control** — permitir ver y controlar qué aplicaciones pueden continuar ejecutándose en background.

- [ ] **Startup Applications / Open at Login** — permitir elegir qué aplicaciones deben iniciarse automáticamente cuando el usuario inicia sesión.

- [ ] **Default Applications / MIME Associations & UI** — parcial: Abrir con muestra y lanza aplicaciones compatibles reales mediante GIO/GAppInfo desde File/Folder, destacando la predeterminada. Falta la UI para cambiar aplicaciones predeterminadas (navegador, reproductor, editor, mail) y elegir aplicaciones no asociadas al MIME; integrar estas opciones mediante las asociaciones existentes de GNOME, sin inventar un registro paralelo.

- [ ] **Application Updates** — integrar actualización de aplicaciones desde Pedro App Store o la infraestructura correspondiente, mostrando claramente versiones disponibles y estado de instalación.

- [ ] **System Update UX** — crear una experiencia única de Pedro para actualizaciones del sistema, ocultando detalles técnicos de `apt`, paquetes y otras herramientas subyacentes.

- [ ] **Firmware Updates** — integrar `fwupd`/LVFS cuando el hardware sea compatible y presentar actualizaciones de firmware mediante la UI de Pedro.

- [ ] **Recovery Environment** — proporcionar mecanismos de recuperación de Pedro para reparar el sistema cuando no pueda iniciar correctamente o alguna actualización cause problemas.

- [ ] **Restore Points / System Snapshots** — investigar e implementar una estrategia de snapshots/restauración del sistema cuando la arquitectura de filesystem lo permita. Mantener separado este concepto de backup de archivos personales.

- [ ] **Crash Reporting** — detectar crashes de aplicaciones Pedro y ofrecer una experiencia limpia con opciones como Reopen, View Details y Send Report, utilizando logs, stack traces o minidumps según corresponda.

- [ ] **Global Search** — implementar una búsqueda global estilo Spotlight capaz de encontrar aplicaciones, archivos, configuraciones, acciones del sistema y resultados rápidos. Natural Language Search es una extensión opcional post-MVP descrita más adelante, no un requisito de esta primera búsqueda.

- [ ] **Searchable Settings** — indexar secciones y acciones de Pedro Settings para que búsquedas como `Wi-Fi`, `Night Light`, `Default Browser`, `Startup Apps`, `Permissions` o `Updates` abran directamente la vista correspondiente.

- [ ] **Quick Look / File Preview** — parcial: los iconos pueden mostrar imágenes locales; falta una experiencia de preview independiente. Permitir previews rápidos de imágenes, PDF, texto, audio, video y otros formatos sin abrir necesariamente la aplicación completa asociada.

- [ ] **Lock Screen / Idle Management** — controlar auto-lock, screen timeout, dimming, comportamiento de tapa y otras políticas de sesión utilizando la infraestructura existente de GNOME/systemd. Inhibir idle, screensaver o suspensión durante juegos activos cuando corresponda.

- [ ] **Online Accounts** — permitir integrar cuentas externas como Google, Microsoft, Nextcloud u otros proveedores compatibles para reutilizarlas en servicios del sistema.

- [ ] **User Accounts / Profiles** — crear experiencia propia de Pedro para usuarios locales, avatar, nombre, contraseña, permisos y configuración de sesión.

- [ ] **Input Methods / Keyboard Sources** — integrar layouts, idiomas e input methods mediante infraestructura como IBus, sin reinventar métodos de entrada.

### Useful but Lower Priority

Estas funcionalidades deben quedar documentadas como deseables, pero no deben bloquear una primera versión usable de Pedro.

- [ ] **Thumbnail Service** — parcial: existen imágenes locales en iconos; falta un servicio compartido de generación/cache. Investigar un servicio centralizado y cacheado de thumbnails reutilizable por Files, File Picker, Global Search y Quick Look.

- [ ] **Remote / Cloud Filesystems** — parcial: Files enumera ubicaciones mediante GIO; falta UI e integración de acceso/autenticación a recursos remotos. Permitir navegar recursos como SFTP, SMB, WebDAV, Nextcloud, Google Drive u otros mediante GIO/GVfs o integraciones equivalentes.

- [ ] **Pedro Device Sharing** — posibilidad futura de compartir archivos entre dispositivos Pedro mediante una experiencia propia, sin depender de AirDrop.

- [ ] **Clipboard Sync Between Pedro Devices** — posibilidad futura de sincronizar clipboard entre dispositivos autorizados del mismo usuario.

- [ ] **Advanced Backup** — estrategia completa de backup de archivos personales, independiente de System Restore/Snapshots.

- [ ] **Extended File Metadata / Tags** — parcial: Files expone metadata básica y presenta etiquetas como UI. Implementar persistencia/edición de tags, atributos extendidos e información reutilizable por Files y Search.

### Architecture Rules

Pedro debe ocultar las tecnologías internas al usuario final. La UI presenta conceptos Pedro: Passwords / Keychain, Notifications, Privacy, Storage, Printers, Battery, Energy, Displays, Default Apps, Location y Permissions.

Internamente puede usar libsecret, GNOME Keyring, XDG Portals, PipeWire, MPRIS, CUPS, UDisks2, udev, GSettings, GeoClue, polkit, UPower, power-profiles-daemon, Mutter, systemd-logind, GIO y journald. Encapsular estas capacidades detrás de PAPI o backends propios cuando corresponda; evitar dependencias directas de la UI en detalles de GNOME/Linux y sistemas paralelos.

- Reutilizar servicios y protocolos maduros de Linux/GNOME; no reimplementarlos desde cero.
- Ocultar también nombres como fprintd, fwupd, IBus, GVfs y XDG Portal en la UI.
- Las aplicaciones deben consumir la API Pedro equivalente cuando exista, en lugar de acceder directamente a servicios internos.
- Development y production comparten arquitectura; no crear implementaciones específicas de Ubuntu development que haya que sustituir al crear el ISO.
- Distinguir System Recovery (reparar un sistema que no arranca), System Restore / Snapshots (restaurar estado del sistema) y User Backup (proteger archivos personales).
- High Priority / Core Experience define la experiencia objetivo de un sistema operativo de uso general. Useful but Lower Priority puede llegar posteriormente y no debe retrasar innecesariamente una primera versión estable.

## Desktop y menú del wallpaper

- [x] Crear carpetas y archivos vacíos con nombres únicos de forma asíncrona, con renombrado en línea.
- [x] Organización cuadrícula, libre y pilas expandibles por tipo; alineación y persistencia de preferencias y posiciones por modo. Ordenación por nombre natural, tipo MIME, fecha reciente y tamaño descendente en los tres modos, con criterio persistente y redistribución explícita; Pila conserva los registros individuales.
- [x] Barreras de arrastre en Libre y Cuadrícula contra logo, menús, widgets y dock, con margen universal de 8 px también en Pila; Cuadrícula busca una celda válida cercana al soltar, con origen local en los bordes de las zonas libres delimitadas por esos controles; las zonas despejadas conservan el origen de pantalla. Pila inicia cada tramo de columna desde el borde del obstáculo anterior, incluido el menú superior.
- [x] Gap de 8 px entre elementos en Cuadrícula y Pila, incluyendo áreas de selección; Libre permite superposición.
- [x] Arrastre visual en pilas: representación bajo el cursor, resaltado de destino y retorno sin modificar posiciones; permite arrastrar elementos de pilas expandidas.
- [ ] Conectar el drop a movimiento asíncrono de archivos/carpetas mediante PAPI, validando destinos, colisiones, errores y progreso. El gesto visual no mueve contenido.
- [x] Copiar/cortar/pegar compartidos en Desktop y Files mediante el portapapeles nativo y MIME de GNOME; menús y Ctrl+C/X/V respetan el foco de campos de texto. Un único gestor PAPI/GIO para pegado y arrastre, progreso Liquid cancelable y conflictos conservando ambos nombres.
- [ ] Conectar Seleccionar todo y orden por nombre/tipo/fecha/tamaño del menú del wallpaper; ampliar agrupación por nombre/fecha. El orden de Files no completa estas acciones del Desktop.
- [ ] Conectar Ajustes de pantalla a la capacidad Displays y la gestión de widgets a su UI; los menús existentes son presentación.
- [x] Sombra mínima de un píxel únicamente en los nombres del componente compartido de carpetas/archivos, para mejorar contraste sobre wallpapers claros.

## Pedro Files

- [x] Panel de información Liquid inspirado en la referencia: icono/nombre reutilizan File/Folder, metadatos GIO reales de tamaño, ubicación, fechas, propietario y permisos. Compartido en columnas, Get Info de Files y una ventana interna desde Desktop; consultas cancelables y protección ante fuentes obsoletas.
- [ ] Conectar Agregar/Editar etiquetas del panel de información a escritura de metadatos GIO/GVfs (`metadata::pedro-tags`) con validación y monitorización; los controles están visibles y deshabilitados. Verificar persistencia y disponibilidad del backend de metadatos en producción.

- [x] Ventana Qt Quick desde dock/lateral, UI light/dark e inglés/español dividida en componentes.
- [x] Modelos PAPI e historial independientes por ventana; listados reales, Inicio y carpetas XDG, Este equipo mediante montajes GIO, Papelera mediante GVfs, Favoritos/Recientes mediante registros GTK. La Papelera se abre desde el dock.
- [x] Vistas cuadrícula, lista, columnas y mixta; orden por nombre, tipo (carpetas primero), tamaño y fecha mediante proxies Qt; scroll del cuerpo completo. En columnas, un clic en archivo muestra detalles y el doble clic abre el visor; las carpetas navegan con un clic.
- [x] File/Folder reutilizables con comportamiento propio: menú, copia/corte, Papelera, arrastre nativo y drop a carpetas. Lista y columnas delegan toda la superficie de interacción; los atajos comparten una política única. El host solo aporta selección, navegación, diálogos y organización del escritorio; verificación con componentes aislados y las cuatro vistas.
- [x] Menú Liquid del espacio vacío, con asociación reactiva a la ventana, para crear carpetas/archivos, pegar, propiedades y las mismas opciones de vista/orden que la barra superior; clic derecho comprobado en cuadrícula, lista, columnas y mixta. Incluye Seleccionar todo, selección compartida para copiar/cortar y organización similar al escritorio; traducciones verificadas en los `.ts` compilados.
- [ ] Implementar Opciones de visualización, incluyendo mostrar archivos ocultos mediante el modelo GIO. La entrada del menú está presente y deshabilitada hasta que tenga funcionalidad.
- [x] Título alterna lateral completo/iconos, animación suave; controles de ventana y resize por bordes/esquinas.
- [ ] Ajustar ancho del lateral arrastrando la división.
- [x] Búsqueda general de archivos y carpetas personales mediante GNOME LocalSearch/Tracker desde PAPI, con resultados fuera de la ubicación abierta, consulta asíncrona cancelable y presentación en las cuatro vistas. GNOME Files activo puede aportar resultados adicionales de su proveedor D-Bus.
- [ ] Distribuir LocalSearch/TinySPARQL (o Tracker 3 según la versión de GNOME) y activar su indexador en la sesión de producción; validar búsqueda de archivos/carpetas y actualización del índice. Ofrecer configuración de ubicaciones personales indexadas, incluidas carpetas compartidas y volúmenes externos; respetar exclusiones de GNOME sin recorrer archivos internos del sistema.
- [ ] Conectar filtros y edición de marcadores; la presentación existe. El soporte de etiquetas se registra en Extended File Metadata / Tags.
- [x] Papelera real mediante GIO/GVfs: enviar desde Desktop/Files y arrastrar al dock, restaurar sin sobrescribir y eliminar/vaciar con confirmación.
- [x] Renombrar y Duplicar reutilizables en File/Folder: menú y F2/Ctrl+D, edición del nombre inline compartida (Enter/clic fuera confirman, Escape cancela), operaciones GIO asíncronas, conflictos sin sobrescritura y actualización del portapapeles al renombrar. Incluye carpetas y enlaces; verificado con backend y UI.
- [x] Seguir renombrados y movimientos en sesiones Preview abiertas: PAPI observa cambios externos mediante GIO y un descriptor Linux retenido; las operaciones de Pedro notifican también destinos efectivos de movimientos, incluidos hijos completados de una transferencia parcial. Se conservan reproducción, página PDF, zoom, geometría y borradores; guardar usa la nueva ruta y rechaza conflictos. Verificado con proveedores/QML y con el Backend de la GUI.
- [ ] Seguir movimientos externos que sean copia/eliminación entre filesystems cuando GIO no informa el destino y el inode cambia. Mantener la protección de borradores y no buscar coincidencias recorriendo el sistema ni inferir el destino por nombre. Verificar además la monitorización de Preview en la futura sesión propia de producción.
- [ ] Completar las demás operaciones de archivos desde el comportamiento común de File/Folder, sin implementarlas por vista; aplicar los jobs definidos en Storage & Filesystem. Reutilizar también los diálogos de navegación, propiedades y confirmación para futuros consumidores mediante `navigationRequested`.
- [ ] Integrar GIO/GVfs y sus backends de Papelera y volúmenes en la futura sesión de producción: distribuir las dependencias y activar sus servicios D-Bus; verificar `trash:///`, restauración, vaciado y monitorización dentro de la sesión propia de Pedro. La validación actual en Ubuntu/GNOME no completa esta integración.

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
- [ ] **Minimizar hacia el dock de Pedro** — conectar el destino de la animación con la posición real del icono correspondiente en el dock de Pedro. Pospuesto para la integración del gestor/compositor definitivo; en la sesión actual GNOME/Ubuntu controla la animación y usa su propio dock. Esta limitación pertenece a la integración con GNOME, no a Parallels; abandonar la VM por sí solo no la resuelve. Mantener la gestión de ventanas en el compositor y la representación del dock en Qt/QML.
- [ ] Menú explícito para abrir una nueva ventana.
- [ ] Distribuir la integración en la futura sesión GNOME de producción cuando se defina su boot/session flow. La integración actual del overlay no confirma el funcionamiento de la ISO.

La extensión requiere una nueva sesión tras instalarse. Mantener Ubuntu/GNOME como gestor de ventanas, sin gestión paralela; el clic normal no debe solicitar otra ventana.

Detalle: [integración GNOME](../gnome/application/readme.md).


## Pedro Terminal

Pedro debe tener una aplicación Terminal propia, visualmente sencilla, ligera y consistente con la experiencia de Pedro.

La intención NO es crear un emulador de terminal desde cero.

- [ ] **Pedro Terminal** — pendiente: el icono de terminal no constituye una aplicación propia. Crear la aplicación Terminal propia de Pedro utilizando Qt6/QML para la experiencia visual.
- [ ] **Terminal Engine** — utilizar `QTermWidget` o una alternativa Qt equivalente y madura para resolver PTY, terminal emulation, ANSI sequences, cursor, scrollback, resize, input/output y ejecución del shell.
- [ ] **Zsh as Default Interactive Shell** — utilizar Zsh como experiencia interactiva predeterminada de Pedro, manteniendo Bash disponible para compatibilidad y usuarios que lo prefieran.
- [ ] **Oh My Zsh Integration & Version Policy** — incluir una versión controlada y validada por release de Pedro, sin depender de configuración manual ni auto-updates externos que produzcan cambios inesperados.
- [ ] **Pedro Zsh Configuration** — crear configuración propia de Pedro sobre Zsh/Oh My Zsh sin eliminar la posibilidad de que usuarios avanzados modifiquen `~/.zshrc`.
- [ ] **Syntax Highlighting** — comandos válidos, inválidos, paths, argumentos y otros tokens deben mostrar highlighting mediante herramientas maduras del ecosistema Zsh.
- [ ] **Autosuggestions** — mostrar sugerencias mientras el usuario escribe utilizando historial y completions.
- [ ] **Tab Completion** — proporcionar autocompletado potente mediante el sistema de completion de Zsh.
- [ ] **Pedro Terminal Theme** — crear un prompt/theme propio, minimalista y visualmente consistente con Pedro.
- [ ] **Terminal Tabs** — soportar múltiples sesiones independientes mediante tabs sin llenar la interfaz de controles innecesarios.
- [ ] **Real Clear / Scrollback Clear** — permitir una acción/shortcut que limpie realmente el terminal y el scrollback visible.
- [ ] **Terminal Search** — permitir buscar texto dentro de la sesión.
- [ ] **Shell Choice** — permitir posteriormente elegir Zsh, Bash u otros shells compatibles si están instalados.

La experiencia visual debe permanecer minimalista. Pedro Terminal debe ocultar complejidad técnica innecesaria y utilizar el shell Unix/Linux real debajo.

Arquitectura esperada:

`Pedro Terminal QML -> integración Qt del motor maduro -> PTY / Zsh -> Oh My Zsh / Pedro configuration -> Linux`

Validar la compatibilidad del motor elegido con Qt6/QML; QTermWidget es un candidato, no una integración ya confirmada.

---

## Pedro Gaming Platform

Pedro debe ofrecer una experiencia gaming integrada y sencilla para que el usuario no tenga que entender manualmente drivers, Vulkan, PRIME, GameMode, Proton, Wine prefixes u otros detalles propios del stack Linux.

La prioridad es:

1. juegos nativos de Pedro/Linux;
2. Steam + Proton para juegos Windows;
3. Wine únicamente como infraestructura secundaria cuando sea necesario para gaming.

No convertir Wine en una capa general visible para ejecutar aplicaciones normales de Windows.

### Graphics & Drivers

- [ ] **GPU Detection** — detectar automáticamente GPUs NVIDIA, AMD e Intel.
- [ ] **GPU Driver Management** — garantizar que se utilice el driver gráfico correcto para el hardware detectado reutilizando la infraestructura de Ubuntu/Linux.
- [ ] **NVIDIA Driver Support** — integrar correctamente drivers NVIDIA compatibles con la release de Ubuntu utilizada por Pedro.
- [ ] **AMD Graphics Support** — utilizar correctamente kernel, Mesa y drivers AMD existentes.
- [ ] **Intel Graphics Support** — utilizar correctamente kernel, Mesa y drivers Intel existentes.
- [ ] **Vulkan Support** — garantizar que Vulkan loader, drivers y capacidades correspondientes estén correctamente disponibles cuando el hardware lo soporte.
- [ ] **Vulkan Capability Detection** — consultar en runtime la versión/capabilities soportadas en lugar de hardcodear una única versión Vulkan para todo Pedro.
- [ ] **OpenGL Compatibility** — conservar soporte correcto para aplicaciones/juegos que dependan de OpenGL.

Pedro no debe implementar drivers gráficos propios.

### Steam / Proton

- [ ] **Steam Compatibility** — garantizar que Steam funcione como una aplicación normal de Pedro.
- [ ] **Proton Gaming Support** — permitir que Steam utilice Proton para ejecutar juegos Windows compatibles.
- [ ] **Transparent Proton UX** — el usuario debería poder instalar un juego y presionar `Play` sin tener que configurar manualmente Wine, Proton prefixes, DXVK o variables internas.
- [ ] **Wine Gaming Fallback** — mantener Wine disponible únicamente cuando sea necesario para gaming fuera de Steam u otros casos específicos.
- [ ] **Gaming Compatibility Metadata** — permitir que Pedro App Store pueda indicar posteriormente si un juego es `Pedro Native`, `Linux Native`, `Proton Compatible` o requiere otra capa de compatibilidad.

### Game Performance

La coordinación con perfiles de energía se registra en **Power Profiles**; la inhibición de idle, screensaver y suspensión, en **Lock Screen / Idle Management**.


- [ ] **GameMode Integration** — integrar Feral GameMode para optimizaciones temporales mientras un juego está activo.
- [ ] **Automatic Gaming Performance Mode** — permitir que Pedro active automáticamente optimizaciones apropiadas al iniciar un juego y restaure el estado anterior al cerrarlo.
- [ ] **Per-Game Performance Profile** — permitir configurar opciones de rendimiento de forma individual por juego.
- [ ] **Process / I/O Optimization** — aprovechar GameMode y servicios existentes para prioridad de CPU, I/O y scheduler cuando sea apropiado.

### Hybrid GPU

- [ ] **Hybrid GPU Detection** — detectar laptops/equipos con iGPU + GPU dedicada.
- [ ] **Automatic GPU Selection** — permitir que Pedro seleccione automáticamente la GPU apropiada.
- [ ] **Per-App / Per-Game GPU Selection** — permitir elegir entre `Automatic`, `Integrated` y `Dedicated GPU`.
- [ ] **PRIME / Render Offload Integration** — reutilizar PRIME, `DRI_PRIME`, NVIDIA Render Offload y mecanismos Linux existentes; no inventar un sistema propio.

### Displays for Gaming

Los modos de alta frecuencia (120, 144, 165 Hz u otros soportados) pertenecen a **Displays, resolución y escala**, sin hardcodear modos.


- [ ] **Variable Refresh Rate / Adaptive Sync** — exponer VRR cuando Mutter, GPU, driver y monitor lo soporten.
- [ ] **HDR Support** — investigar e integrar HDR cuando la release concreta de Mutter/Linux/drivers utilizada por Pedro lo soporte con suficiente estabilidad.
- [ ] **Per-Game Display Preferences** — considerar en el futuro preferencias de display específicas por juego cuando tenga sentido.

### Controllers

- [ ] **Game Controller Support** — soportar controles Xbox, PlayStation y gamepads genéricos utilizando la infraestructura de input existente en Linux.
- [ ] **USB / Bluetooth Controllers** — detectar controles conectados mediante USB o Bluetooth.
- [ ] **Controller Information** — mostrar información disponible como dispositivo conectado y batería cuando el hardware/driver lo permita.

### Pedro Native Gaming

La integración de juegos con PAPI/SDK y su distribución se registra en **Pedro SDK / PAPI** y **Pedro Package Format**, respectivamente.


- [ ] **Game Engine Target Support** — preparar documentación/APIs para que engines como Unreal, Unity, Godot u otros puedan eventualmente ofrecer `Pedro` como target de exportación.
- [ ] **Native Vulkan/Linux Foundation** — un juego Pedro nativo debe poder utilizar APIs estándar como Vulkan/OpenGL/SDL y agregar integración Pedro mediante el SDK cuando sea necesario.

Arquitectura:

`Pedro Game / Steam -> Vulkan/OpenGL -> Mesa/NVIDIA/Intel/AMD drivers -> GPU`

Para juegos Windows:

`Steam -> Proton -> DXVK/VKD3D/Wine components -> Vulkan -> Linux drivers -> GPU`

Pedro debe ocultar esta complejidad al usuario final.

---

## Pedro Developer Experience

No convertir el ISO base en una distribución llena de toolchains innecesarios.

La prioridad es que instalar herramientas de desarrollo sea extremadamente sencillo.

- [ ] **Pedro Package Manager (`pkg`) / Simple Installation** — crear una interfaz propia de Pedro encima de APT/repositorios compatibles, con comandos sencillos como:
  - `pkg add gcc`
  - `pkg add clang`
  - `pkg add node`
  - `pkg add python`
  - `pkg add cmake`
- [ ] **Repository Abstraction** — el usuario no debe necesitar conocer APT, repositorios Debian/Ubuntu, PPAs u otros detalles cuando exista una operación equivalente de Pedro.
- [ ] **Version Policy** — Pedro puede definir versiones recomendadas/compatibles de herramientas por release.
- [ ] **Developer Tool Discovery** — si el usuario intenta utilizar una herramienta que no está instalada, Pedro puede ofrecer instalarla mediante `pkg`.
- [ ] **Pedro SDK / PAPI** — parcial: PAPI ya expone capacidades a la GUI; falta un SDK público y su integración/documentación para aplicaciones y juegos nativos.
- [ ] **Pedro Package Format** — definir empaquetado propio para aplicaciones y juegos Pedro, conservando Ubuntu/Debian como base interna.

No preinstalar Node.js, Python SDKs, Docker, Podman, Rust, Go, Java y otros toolchains solamente por ser populares. Deben poder instalarse fácilmente cuando sean necesarios.

---

## Pedro Intelligent Search — Optional / Post-MVP

Esta funcionalidad es deseable pero NO debe bloquear una primera versión estable de Pedro.

No se busca crear un asistente general equivalente a ChatGPT, Codex, Siri o Cortana.

El objetivo es extender Pedro Global Search/Spotlight para que pueda entender consultas naturales y encontrar información local del sistema de forma inteligente.

- [ ] **Natural Language Search** — permitir búsquedas como:
  - `muéstrame la última factura de Con Edison`
  - `¿dónde guardé el contrato del apartamento?`
  - `muéstrame PDFs sobre impuestos`

### Menús rápidos del escritorio

- Mantener paneles compactos en píxeles lógicos, con Liquid compartido: Ethernet 300 × 270; Bluetooth/Wi-Fi 304 de ancho y altura según estado/lista, limitada a cuatro filas antes de desplazar. Control Center 328 de ancho y altura derivada del contenido; System 288 × 288. Priorizar reducir espacio sobrante frente a encoger texto y conservar listas desplazables.

### Seguimiento de estabilidad de Files

- [x] Reproducir y corregir el cierre al navegar carpetas: GDB capturó `free(): invalid pointer` en `g_mount_spec_unref`, desde el objeto `trash:///` que PAPI creaba para cada entrada local en consultas concurrentes. Se elimina esa creación innecesaria y se consulta el padre únicamente para entradas de la papelera. La regresión cubre carpetas vacías, navegación profunda, scroll y retirada segura de columnas.

- [ ] Revisar la comprobación de redimensionado del panel externo de Información en la suite GUI completa de Wayland: falla con la secuencia de eventos sintéticos de QtTest, mientras la suite offscreen y la ejecución nativa enfocada en cierre/reapertura de Información y rueda suave pasan. Verificar la secuencia y la entrada nativa antes de atribuirlo a un fallo del producto.

### Regla permanente de interfaz: barras de desplazamiento

- Las barras de scroll de Pedro se muestran **solamente cuando el contenido desborda el área visible en ese eje**. Si todo cabe, la barra se oculta; se recalcula al cambiar el contenido, el ancho o la altura. Usar `ScrollBar.AsNeeded` y, en barras personalizadas, vincular también `visible` al desbordamiento (`size < 1`). Esta regla aplica a columnas, Información, listas, visores, editores y paneles del sistema. No usar `AlwaysOn` como valor predeterminado.

### Carpetas grandes y navegación del sistema

- [x] Corregir apertura de las direcciones internas de Computer/Favorites/Recent en columnas y usar inserción inicial por lote en PAPI. Virtualizar cuadrícula y vista mixta para mantener únicamente los delegados visibles; probar 2.100 archivos y la navegación por `/bin` y `/usr/bin` en Wayland. Mostrar carga y errores nativos de lectura.
- [ ] Si el cierre original reportado en `/bin` reaparece con esta versión, capturar su traza y vista exacta. No se reprodujo un aborto en la prueba mantenida abierta; sí se confirmó que la vista mixta creaba 1.761 filas a la vez, reducidas a unas 18 tras la corrección.

- [x] Filtros contextuales de Files: mostrar únicamente las categorías MIME presentes en la carpeta/vista activa o resultados de búsqueda, ocultar la barra con cero/un tipo, filtrar mediante proxies Qt de PAPI y actualizar las opciones ante cambios de archivos. Mantener All y las opciones disponibles mientras se selecciona un filtro.
