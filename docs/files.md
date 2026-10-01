# Pedro Files

La ventana Qt Quick del dock y la navegación lateral reutiliza un controlador de navegación por ventana (`gui/qml/controllers/files/navigation.qml`) y una instancia independiente de `Pedro::Papi::Io::Directory::Model`. QML representa el modelo y solicita navegación; PAPI resuelve ubicaciones, enumera y observa el filesystem.

## Ubicaciones

- Inicio enumera el Home real obtenido por GLib, sin elementos de muestra ni una ruta por usuario.
- Documentos, Descargas, Imágenes, Música, Vídeos y las demás carpetas estándar se resuelven mediante [`g_get_user_special_dir`](https://docs.gtk.org/glib/func.get_user_special_dir.html). Inicio crea las ubicaciones XDG configuradas que faltan; seleccionar una de ellas también asegura su existencia. Si una ubicación no está configurada, se comunica el error sin inventar una ruta.
- Este equipo muestra la raíz del filesystem y los volúmenes montados reportados por `GVolumeMonitor`. No depende del nombre del usuario, una VM o dispositivos específicos.
- Papelera enumera `trash:///` mediante GIO/GVfs, incluyendo navegación en carpetas eliminadas. `make setup` incluye GVfs y sus backends; la sesión debe proporcionar los servicios D-Bus normales de GVfs.
- Favoritos utiliza los marcadores GTK 3/4 del usuario, conserva sus nombres y elimina duplicados. No equivale al sistema de estrellas de Nautilus/Tracker.
- Recientes utiliza el registro compartido `recently-used.xbel` del usuario, muestra destinos existentes y ordena por la última visita registrada. Solo aparecen archivos registrados por aplicaciones que participan en ese mecanismo.
- Pedro Drive y Proyecto Pedro no son destinos reales y se retiraron de la navegación.

La resolución es la misma en development y production. La futura sesión de producción debe distribuir y arrancar los backends de GIO/GVfs requeridos; no crear otra implementación de Papelera o de montajes.

## Interacción y actualizaciones

Un clic en una ubicación cambia el directorio; un doble clic en una carpeta entra en ella. Atrás/adelante utiliza el historial del controlador/modelo de esa ventana. Seleccionar un elemento resalta su tarjeta o fila. El navegador no muestra un panel lateral de detalles.

Las consultas GIO y la creación de directorios se ejecutan en workers de Qt Concurrent con `GCancellable`. Cambiar de ubicación cancela la consulta anterior y descarta resultados obsoletos mediante generaciones. La GUI aplica los resultados en su propio hilo.

[`GFileMonitor`](https://docs.gtk.org/gio/class.FileMonitor.html) observa la carpeta abierta y se reemplaza al navegar. Los eventos se agrupan durante 120 ms, disparan una enumeración asíncrona y se reconcilian por URI mediante inserciones, movimientos, eliminaciones y cambios de datos. No hay polling, refresco por frame ni mensaje periódico de “Refreshing”. Los modelos proxy separan carpetas y archivos y conservan actualizaciones incrementales. Las vistas GridView/ListView virtualizan y desplazan los elementos visibles.

## Pendiente

Las vistas cuadrícula, lista, columnas y mixta se seleccionan mediante un dropdown de la barra superior. Cuadrícula reúne carpetas y archivos como iconos con el nombre debajo; mixta combina carpetas con ese mismo diseño y archivos en filas. No se muestran tarjetas de fondo ni encabezados de categorías. Lista reúne todos los elementos, con sus iconos normales. Columnas abre las carpetas seleccionadas en la siguiente columna, con una instancia independiente del modelo PAPI por columna visible. Cada instancia conserva su enumeración asíncrona y monitor de directorio. La navegación lateral comparte el fondo Liquid de la ventana y tiene una división fina. Se retiró el botón para contraerla; el futuro ajuste mediante arrastre queda pendiente. El dropdown de orden utiliza proxies Qt del modelo PAPI para nombre, tipo, tamaño o fecha (más recientes primero). La lista utiliza todo el alto del cuerpo y la vista mixta comparte un scroll general sin un límite fijo de altura. Las barras de scroll usan gris cálido. Búsqueda se presenta como un icono que despliega un campo de ancho fijo; los filtros de categoría, búsqueda y etiquetas siguen siendo UI; el listado ocupa todo el espacio restante, sin panel de información. No confundirlos con las operaciones ya disponibles en el menú del Desktop. Apertura de archivos con aplicaciones, marcadores editables, restaurar/vaciar Papelera y montaje de dispositivos aún no se implementan.
