# Desktop del usuario activo

Flujo: Pedro Desktop UI → `Backend.desktopModel` → `Pedro::Papi::Io::Desktop::Model` → XDG/GLib/GIO → Desktop real.

El modelo reside en `papi/io/desktop/model.hpp` y `model.cpp`. Se llama `Model` porque su namespace ya aporta el contexto Desktop. La GUI expone ese modelo como `QAbstractItemModel`; no enumera archivos ni resuelve rutas en QML.

## Resolución de la carpeta

`g_get_user_special_dir(G_USER_DIRECTORY_DESKTOP)` obtiene la configuración XDG del usuario que ejecuta la sesión. No hay rutas particulares para development ni production. La sesión de la ISO debe ejecutar la GUI como el usuario que inició sesión, con su entorno de usuario.

La ruta se resuelve al iniciar el modelo y se conserva durante la sesión. GLib mantiene en caché las carpetas especiales: cambiar `user-dirs.dirs` durante la sesión requiere reiniciar Pedro para esta implementación.

Pedro no inventa rutas ni crea carpetas al enumerar. Si la carpeta no está disponible o no es accesible, expone el error mediante la propiedad `error` del modelo. GLib conserva su propio comportamiento estándar de fallback cuando no existe configuración XDG.

## Modelo y eventos

La enumeración inicial usa `g_file_enumerate_children_async` y lotes de `g_file_enumerator_next_files_async`. Los elementos visibles incluyen nombre, URL, ruta, tipo, tamaño y fecha de modificación. Los archivos ocultos se omiten. Las imágenes representan el archivo real, no el wallpaper configurado.

Un `GFileMonitor` observa el Desktop antes de comenzar la enumeración para preservar los eventos que lleguen durante la carga. Los cambios se agrupan durante ventanas de 100 ms mediante un temporizador de una sola ejecución; no hay polling ni consultas por frame.

Creación, eliminación, renombrado y modificación desencadenan consultas asíncronas de los elementos afectados. Las revisiones descartan respuestas obsoletas. El modelo emite inserciones, eliminaciones y cambios de filas, sin resetear la vista. QML mantiene la selección, el arrastre y los menús existentes.

GIO entrega sus callbacks a través del contexto GLib integrado en el event loop de Qt de Ubuntu. La sincronización depende de las notificaciones disponibles en el filesystem anfitrión; no se agrega polling como alternativa. El modelo cancela su monitor y las operaciones pendientes al destruirse.

Referencias: [resolución de carpetas especiales en GLib](https://docs.gtk.org/glib/func.get_user_special_dir.html) y [eventos de GFileMonitor](https://docs.gtk.org/gio/class.FileMonitor.html).

El menú del wallpaper crea carpetas y archivos vacíos mediante las APIs asíncronas de GIO en PAPI. La creación usa nombres únicos ante colisiones, sin sobrescribir contenido. Al completar la creación, la UI selecciona el elemento y abre un editor de nombre en línea: Enter o perder el foco confirma; Escape conserva el nombre inicial. El renombrado usa `g_file_set_display_name_async`, valida nombres simples y muestra errores sin bloquear la interfaz.

Las demás acciones sobre archivos del menú contextual, los ajustes de pantalla, los widgets y el monitor de Pedro Files siguen pendientes.

## Organización

PAPI guarda el modo de organización y la preferencia de alineación en la configuración del usuario. QML decide únicamente la disposición visual.

- **Cuadrícula:** restaura las posiciones guardadas para este modo y coloca los elementos nuevos en celdas disponibles. «Mantener alineado» controla si los arrastres se ajustan a la cuadrícula.
- **Libre:** conserva coordenadas exactas al soltar, sin ajustarlas a celdas. Mantiene los límites de la pantalla y evita superponer elementos a los controles del shell.
- **Pila:** el modelo aporta grupos por tipo (carpetas, imágenes, documentos, audio, vídeo y otros archivos). La UI coloca las pilas junto al borde derecho, de arriba hacia abajo, evitando los controles del shell y continuando en columnas hacia la izquierda cuando sea necesario. Muestra representantes con contadores; un clic expande o contrae cada pila. Este modo no sobrescribe las posiciones individuales ni permite arrastrar las pilas. Al volver a libre se recuperan las posiciones individuales guardadas.

Las marcas del menú reflejan el modo y la alineación reales. La selección del modo se conserva entre sesiones. Las opciones de agrupación por nombre y fecha quedan pendientes.

## Posiciones del escritorio

Al terminar un arrastre, QML entrega al modelo las coordenadas finales de cada elemento seleccionado. PAPI las guarda mediante `QSettings` en `pedro/desktop.ini`, dentro de la carpeta de configuración XDG del usuario, y las devuelve en el campo `position` de cada entrada. El mismo almacenamiento se utiliza en development y production.

La identidad de archivo de GIO permite conservar la posición al renombrar un elemento cuando el filesystem la proporciona; también se conserva una clave basada en su URL. Los cambios de metadatos no eliminan las posiciones. Al iniciar otra sesión, QML restaura las coordenadas, las limita a la pantalla actual y evita colocar el elemento sobre los controles de Pedro. Las posiciones guardadas reservan espacio frente a la colocación inicial de elementos nuevos.

Cuadrícula y libre mantienen registros de posiciones independientes. Antes de cambiar de modo se conserva la disposición actual; pila nunca escribe posiciones individuales. Volver desde pila restaura el registro del modo elegido, incluso después de reiniciar Pedro. Los registros anteriores compartidos se siguen leyendo como fallback para conservar compatibilidad.

## Verificación

Validado en Ubuntu con una carpeta XDG de prueba cuyo nombre contiene espacios: carga inicial, clasificación de carpetas e imágenes, exclusión de ocultos, creación, modificación, renombrado, eliminación, movimientos hacia dentro y fuera del Desktop, ráfagas de 40 archivos, actualizaciones sin reset y destrucción con operaciones pendientes. La misma prueba se ejecuta con y sin development mode.

La compatibilidad de rutas utiliza el mismo código en ambos modos. Esto no constituye una prueba de arranque de la ISO.
