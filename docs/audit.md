# Diagnóstico de funcionamiento de Pedro

Fecha: 4 de octubre de 2026.

Se probó el `pedro-gui` de desarrollo en la sesión real GNOME/Wayland de Ubuntu, con PAPI y sus bibliotecas nativas. Se abrió una instancia adicional con archivos de prueba bajo `build/`, sin modificar los documentos del usuario. Las acciones se ejecutaron mediante los controladores Qt y las APIs reales; no fue un recorrido manual con el ratón. No se construyó una imagen ni se probó el arranque del compositor propio de Pedro. El menú lateral pendiente no se evaluó como una función terminada.

## Fallos confirmados

### Prioridad alta: dos instancias del backend

`gui/backend/main.cpp` crea un `Backend` y lo expone como propiedad de contexto. La misma clase se registra como singleton QML `Papi` en `gui/backend/backend.hpp`; ese singleton crea otro objeto.

En una ventana real, `Backend === Papi` y `Backend.audioVolume === Papi.audioVolume` dieron `false`. El proceso normal de Pedro tenía dos procesos hijos `pw-mon`. Los controladores y componentes usan ambas referencias, por lo que existen gestores, monitores, refrescos y estados independientes para las mismas capacidades.

Propuesta: registrar el singleton sobre la instancia existente y mantener temporalmente `Backend` como alias del mismo objeto. Verificar identidad, una sola instancia de cada gestor y coherencia de estado antes de migrar nombres QML.

### Prioridad alta: realimentación en la consulta del volumen

En una prueba con un solo `Pedro::Papi::Audio::Volume::Manager`, sin cambiar el volumen, se recibieron 19 notificaciones `changed` en tres segundos. Una segunda ejecución recibió 22. El volumen permaneció en 97. Un monitor de PipeWire registró 39 apariciones de la propiedad `application.name = "wpctl"` en tres segundos; esas apariciones no equivalen necesariamente a 39 procesos distintos.

`papi/audio/volume/manager.cpp` descarta el contenido de cualquier evento de `pw-mon` y programa otra lectura. La lectura lanza `wpctl`, que también crea y elimina un cliente de PipeWire y genera eventos. Se emite `changed` incluso si el valor no cambió. Los dos backends multiplican este trabajo.

Propuesta: observar únicamente los cambios relevantes del dispositivo de salida y del volumen, excluir eventos de clientes de consulta y emitir notificaciones solamente ante cambios de estado. Preferir una suscripción nativa de PipeWire/WirePlumber cuando se amplíe este proveedor. Medir en reposo y comprobar también cambios realizados desde GNOME y cambios del dispositivo predeterminado.

### Prioridad media: foco ambiguo con nombres repetidos

Se abrieron dos archivos de prueba diferentes, `one/note.txt` y `two/note.txt`, en dos visores. Mientras ambos estaban abiertos, `org.pedro.Applications.ActivateWindow(pid, "note.txt")` devolvió `false`.

La extensión compara PID y título; rechaza más de una coincidencia. Eso evita activar una ventana incorrecta, pero impide que la integración identifique el visor elegido. La solicitud vuelve al mecanismo Qt, que puede ser rechazada en Wayland y producir el aviso de ventana lista.

Propuesta: asociar cada sesión de visor con una identidad estable de ventana del compositor y activar por esa identidad, conservando el título visible sencillo. Probar nombres iguales en carpetas distintas, ventanas minimizadas y cambios de workspace.

### Prioridad menor: pérdida del BOM UTF-8 al vaciar un documento

Se abrió mediante el gestor real un archivo con bytes `ef bb bf 41 0a`. Se guardó texto vacío y después `é`. Ambas operaciones informaron éxito, pero el resultado fue `c3 a9`, sin el BOM original. El caso equivalente UTF-16 conservó su BOM (`ff fe e9 00`); no se observó una pérdida general de la codificación.

`papi/gui/preview/text/provider.cpp` vuelve a deducir codificación y BOM a partir de los últimos bytes guardados. Un guardado vacío UTF-8 pierde esa información.

Propuesta: conservar la codificación y la presencia del BOM como metadatos de la sesión, independientemente de su contenido. Añadir una comprobación de guardar vacío y continuar escribiendo para UTF-8 con BOM, UTF-16 y CRLF.

## Funciones que pasaron

- Tres carpetas independientes y visores simultáneos de imagen, PDF, código y video en ventanas reales.
- Video inicialmente pausado, reproducción con avance de tiempo, pausa, salto a 500 ms y foco al reabrir el mismo video. No se creó otro visor.
- Cierre de los visores y carpetas: quedaron cero sesiones, ventanas administradas y reservas de colocación en la instancia de prueba.
- Proveedores nativos de imagen, PDF, texto, audio y video; navegación de páginas PDF, archivos dañados, límites de texto, guardado automático y detección de conflictos externos, según la prueba de integración del visor.
- Copiar y cortar archivos, copiar carpetas, colisiones de nombres, protección contra copia recursiva y disponibilidad del portapapeles en una plataforma de prueba aislada.
- Orden del escritorio, modos libre/cuadrícula/pila, persistencia y actualizaciones del sistema de archivos.
- Configuración de teclado, nombres de variantes, lista vacía y notificaciones, utilizando GSettings en memoria.
- 52 transiciones de menús sin desconexión Wayland. La prueba de visibilidad de ventanas de menú se validó además en X11: Wayland puede rechazar un popup abierto por un temporizador sin un evento real de entrada.
- La sesión GNOME ofrece `ActivateWindow`, `PlaceWindow`, `Capture`, `StopCapture` y `GetRunning`. La red está conectada por Ethernet; no hay dispositivo Wi-Fi en esta máquina. PipeWire, WirePlumber y UPower están presentes.

La reproducción se comprobó por estado y avance temporal; no se verificó de oído la salida de audio. No se capturó ni grabó el escritorio real del usuario para comprobar `Capture`; se probó su controlador con un servicio de prueba.

## Pruebas antiguas y avisos

Tres comprobaciones no pasaron. Sus errores se separan de los fallos de producto anteriores:

- `gui/tests/icons/mime.cpp` exige representación `themed` para todos los archivos que no son imágenes. Ahora los documentos tienen representación `document`, por decisión de diseño. El fallo detiene la prueba antes de las comprobaciones posteriores del proveedor de iconos.
- El controlador de captura pasó su prueba con un servicio D-Bus aislado, pero `gui/tests/capture/bridge.py` llama a `_lowerDesktop`, un método eliminado en los cambios locales existentes. Falla el fixture del puente.
- `gui/tests/capture/resize.cpp` busca `captureTimer10` dentro de la ventana original. El menú de opciones ahora puede vivir en una ventana popup independiente. La prueba falla en la búsqueda del temporizador; eso no demuestra que el temporizador falte en la interfaz. Es necesario actualizar la prueba para inspeccionar la ventana correcta y volver a comprobar las acciones posteriores.

El test de ordenación emitió un aviso de tipo Qt inválido aunque sus comprobaciones pasaron. Las aperturas y cierres rápidos de varios editores produjeron avisos `QtWaylandTextInputv3::disableSurface` sobre la superficie enfocada, sin un cierre de aplicación. Falta una prueba específica de composición de texto/IME antes de atribuirles un fallo funcional.

## Evidencia y reproducción

Los registros y fixtures de esta ejecución están bajo `build/diagnostic/` y `build/verification/`; son desechables. Los principales registros son `audit/native-final.log`, `audit/duplicate.log`, `audit/duplicate-focus.log`, `audit/behavior.log`, `audit/utf8.log` y `audit/pipewire.log`, dentro de `build/diagnostic/`.

Comprobaciones reutilizables:

```bash
make gui-build
bash gui/tests/clipboard/check.sh
bash gui/tests/desktop/sort.sh
bash gui/tests/keyboard/check.sh
python3 gui/tests/menu/check.py
QT_QPA_PLATFORM=xcb python3 gui/tests/menu/check.py
gjs gui/tests/desktop/grid.js gui/qml/scripts/desktop/grid.js gui/qml/controllers/Application.qml
gjs gui/tests/desktop/placement.js gui/qml/scripts/window/placement.js
gjs gui/tests/window/activation.js gnome/application/extension.js
```

Para los proveedores del visor, usar el target `pedro-preview-check` según `gui/tests/preview/readme.md`. Las tres pruebas que requieren actualizarse son `gui/tests/icons/mime.sh`, `gui/tests/capture/check.sh` y `gui/tests/capture/resize.sh`.

Orden recomendado: unificar el backend, eliminar la realimentación del audio, dar identidad estable al foco de ventanas y preservar el BOM al guardar vacío. Actualizar las pruebas obsoletas junto con cada responsabilidad relacionada. Esta auditoría no cambia esas implementaciones.

## Correcciones y verificación posterior

Se corrigieron los cuatro fallos confirmados de esta auditoría:

- `Backend` y el singleton QML `Papi` comparten ahora el objeto creado por `main.cpp`. La ejecución real devolvió `true` para ambas comparaciones de identidad y mostró un único proceso hijo `pw-dump`.
- Audio observa los registros JSON de `pw-dump --monitor` y descarta eventos de clientes como `wpctl`. Solo notifica cambios efectivos de estado. El gestor real emitió una notificación inicial en tres segundos en reposo, frente a 19–22 antes. El fixture aislado comprobó fragmentación JSON, ruido de clientes, cambios externos de volumen/mute y cambio de salida predeterminada: cuatro consultas y tres notificaciones de estado.
- La colocación devuelve la secuencia estable de Mutter; Pedro conserva esa identidad y la utiliza para enfocar la ventana exacta. Las solicitudes de colocación se serializan y el foco solicitado antes de terminar se conserva. El fixture GNOME comprobó títulos duplicados, pertenencia al proceso, identidades inexistentes y compatibilidad con el método anterior. La extensión actualizada está instalada; el servicio de la sesión actual sigue usando el módulo anterior. **Cerrar sesión y volver a entrar en GNOME es necesario para comprobar este cambio con Mutter real.**
- El proveedor de texto conserva la codificación y el BOM durante toda la sesión. Las pruebas nativas pasaron el ciclo borrar todo → escribir nuevamente en UTF-8 y UTF-16, incluyendo CRLF, guardado atómico y protección ante modificaciones externas.

Se actualizaron las pruebas de iconos y captura para documentos y ventanas popup. Al completar esta última apareció otro fallo: Escape dejaba de cerrar la captura después de cerrar los menús nativos. Un `Shortcut` de ámbito de ventana evita depender del elemento que conserva el foco. La prueba pasó tanto el Escape del submenú (conserva la captura) como el Escape posterior del visor de captura, además de sus comprobaciones de redimensionado, movimiento y opciones.

`make gui-build`, `pedro-preview-check`, las comprobaciones de audio, iconos, captura y activación GNOME pasaron. La ejecución real abrió imágenes, vídeo inicialmente pausado, PDF, texto y carpetas; reprodujo, pausó, buscó y cerró todas las ventanas sin dejar sesiones ni reservas. Los menús pasaron 52 transiciones tanto en Wayland como en X11; el fixture comprueba también la identidad compartida de `Backend` y `Papi`. Los registros de esta revisión son `build/diagnostic/fixes-*.log`.

Los avisos de tipo Qt inválido en la prueba de ordenación y de `QtWaylandTextInputv3::disableSurface` al abrir/cerrar editores rápidamente siguen presentes. Sus pruebas funcionales pasaron; no se da por resuelta una posible incidencia de IME ni se atribuyen estos avisos a un fallo demostrado. No se cambió el compositor de la imagen ni se probó su arranque.
