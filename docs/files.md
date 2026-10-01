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

La carpeta actual permanece visible en la barra superior incluso en ventanas pequeñas. Pulsar su nombre muestra la ruta completa (o URI para ubicaciones virtuales) en un campo de solo lectura seleccionable, con Ctrl+C. Pulsar fuera del campo, cambiar el foco a otra ventana o usar Escape restaura el nombre. Su ancho se adapta al nombre y se amplía para la ruta, con límites de 220 a 320 píxeles para el nombre (adaptándose al espacio disponible en ventanas estrechas) y hasta 480 para la ruta, respetando el espacio disponible.

Los componentes reutilizables `gui/qml/components/entry/folder.qml` y `file.qml` comparten presentación y menú en `entry/item.qml` y `entry/menu.qml`. Cada elemento carga el menú Liquid bajo demanda, configura las acciones de carpeta o archivo y emite solicitudes al controlador de la vista. Escritorio, cuadrícula, lista y columnas los reutilizan; el contexto de selección, navegación y arrastre permanece en los controladores correspondientes. Las operaciones de archivos pendientes no se implementan en los componentes visuales.

Un clic en una ubicación cambia el directorio; un doble clic en una carpeta entra en ella. Atrás/adelante utiliza el historial del controlador/modelo de esa ventana. Seleccionar un elemento resalta su tarjeta o fila. El navegador no muestra un panel lateral de detalles.

Las consultas GIO y la creación de directorios se ejecutan en workers de Qt Concurrent con `GCancellable`. Cambiar de ubicación cancela la consulta anterior y descarta resultados obsoletos mediante generaciones. La GUI aplica los resultados en su propio hilo.

[`GFileMonitor`](https://docs.gtk.org/gio/class.FileMonitor.html) observa la carpeta abierta y se reemplaza al navegar. Los eventos se agrupan durante 120 ms, disparan una enumeración asíncrona y se reconcilian por URI mediante inserciones, movimientos, eliminaciones y cambios de datos. No hay polling, refresco por frame ni mensaje periódico de “Refreshing”. Los modelos proxy separan carpetas y archivos y conservan actualizaciones incrementales. Las vistas GridView/ListView virtualizan y desplazan los elementos visibles.

## Pendiente

Las vistas cuadrícula, lista, columnas y mixta se seleccionan mediante un dropdown de la barra superior. Cuadrícula reúne carpetas y archivos como iconos con el nombre debajo; mixta combina carpetas con ese mismo diseño y archivos en filas. No se muestran tarjetas de fondo ni encabezados de categorías. Lista reúne todos los elementos, con sus iconos normales. Columnas abre las carpetas seleccionadas en la siguiente columna, con una instancia independiente del modelo PAPI por columna visible. Cada instancia conserva su enumeración asíncrona y monitor de directorio. La navegación lateral comparte el fondo Liquid de la ventana y tiene una división fina. Pulsar el título de la ventana alterna entre nombres e iconos; el cursor de manita identifica el título interactivo. El futuro ajuste mediante arrastre queda pendiente. Archivos abre inicialmente con su anchura mínima, limitada al espacio disponible de la pantalla; al volver a mostrar una ventana ya abierta conserva el tamaño que le dio el usuario. El dropdown de orden utiliza proxies Qt del modelo PAPI para nombre, tipo, tamaño o fecha (más recientes primero). Por tipo, las carpetas aparecen primero; los archivos se agrupan por tipo y los nombres desempatan alfabéticamente. La lista utiliza todo el alto del cuerpo y la vista mixta comparte un scroll general sin un límite fijo de altura. Las barras de scroll usan gris cálido. Búsqueda se presenta como un icono que despliega un campo de ancho fijo con la lupa dentro del input y vuelve al icono al pulsar fuera, perder la activación de la ventana o usar Escape; los filtros de categoría, búsqueda y etiquetas siguen siendo UI; el listado ocupa todo el espacio restante, sin panel de información. No confundirlos con las operaciones ya disponibles en el menú del Desktop. Apertura de archivos con aplicaciones, marcadores editables, restaurar/vaciar Papelera y montaje de dispositivos aún no se implementan.

El lateral y la posición de las flechas animan juntos durante 240 ms. Contraído, las flechas quedan junto al título, cuyo ancho respeta la traducción. La altura mínima e inicial de Archivos es 720 píxeles, limitada al espacio disponible del display.

Los menús contextuales de carpetas y archivos usan `Popup.Window` de Qt: pueden sobresalir de la ventana que los abrió y Qt gestiona su ubicación en pantalla. Cada popup conserva el Liquid con una textura local del wallpaper configurado, evitando compartir texturas entre ventanas Qt. El límite de altura pertenece al display, no al navegador.

Un clic derecho en el espacio vacío del cuerpo abre el menú Liquid de la carpeta actual; en columnas se utiliza la ubicación de la columna pulsada. Nueva carpeta y Nuevo archivo crean nombres únicos mediante GIO en un worker de Qt Concurrent, sin sobrescribir elementos existentes ni bloquear la UI. Las ubicaciones virtuales deshabilitan la creación. Propiedades muestra el nombre, la ruta o URI y el número de elementos de esa ubicación. Los errores se muestran en el navegador.

El hover de los elementos usa gris translúcido y cursor de manita en cuadrícula, lista y columnas. El azul se reserva para la selección o la columna navegada.

La interacción de `entry/folder.qml` y `entry/file.qml` se centraliza en `entry/item.qml` y `controllers/entry/action.qml`: selección, doble clic y Abrir del menú comparten el mismo despacho. Los hosts pasan el elemento y su controlador de navegación; las filas y el escritorio delegan sus gestos al componente cuando necesitan conservar su propio layout o arrastre. No existe un menú de carpeta separado para el escritorio.

Un doble clic o Abrir sobre una carpeta del Desktop presenta la ventana de Archivos existente y navega a su URI real. Si su controlador todavía está cargando, conserva la solicitud hasta que esté disponible. La ubicación Desktop del lateral utiliza `openPlace("desktop")` y la configuración XDG del usuario, igual que el modelo del escritorio.

Un clic primario en el espacio vacío del cuerpo limpia la selección en cuadrícula, lista, mixta y columnas. Un handler pasivo conserva los gestos de scroll y los clics de los componentes compartidos. El escritorio conserva su selección mediante arrastre y limpia la selección al pulsar su fondo, salvo Ctrl para selección aditiva.

Los dropdowns de vista y orden presentan un ícono por opción y un radio exclusivo a la derecha, con el estilo de Arrange. Elegir una opción aplica el cambio y cierra el menú. Las filas de lista no muestran el acceso de tres puntos; conservan el menú contextual compartido mediante clic derecho.

Los menús nativos y sus submenús deben tener dimensiones estrictamente positivas antes de abrirse. Wayland rechaza una altura cero como error fatal de protocolo. Los submenús definen su altura desde el contenido y padding; la primera apertura contextual ocurre directamente desde el evento, sin `Qt.callLater`. Esta regresión se reprodujo con eventos reales de Mutter y se verifica en Wayland, además de las pruebas de interfaz.
