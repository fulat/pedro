# Activación de aplicaciones en GNOME

Pedro es una capa sobre la sesión Ubuntu. Un clic en el dock debe activar la aplicación, no solicitar una ventana nueva.

`applications@pedro` ofrece una interfaz D-Bus de sesión mínima: `org.pedro.Applications`, objeto `/org/pedro/Applications`, métodos `Activate(s)` y `GetRunning() → as`. Reutiliza `Shell.AppSystem` y `Shell.App.activate_full()`; GNOME correlaciona desktop entries con ventanas, restaura minimizadas, cambia workspace y gestiona el foco. Cada solicitud obtiene un timestamp actual con `Meta.Display.get_current_time_roundtrip()`: una petición D-Bus no tiene un evento de entrada de Shell y reutilizar su último timestamp puede producir “ready” en lugar de foco. No se ejecuta código arbitrario ni se habilita `unsafe_mode`/`Eval`.

PAPI `Gui::Application::Manager::activate()` llama la integración desde el worker existente del backend. `launch()` permanece separado para una futura acción explícita de abrir una ventana nueva. Los indicadores usan aplicaciones con ventanas reportadas por GNOME cuando la integración está activa, conservando la detección por procesos como fallback. Los clics simultáneos de una misma aplicación no duplican solicitudes pendientes.

Sin la integración, PAPI puede lanzar aplicaciones cerradas mediante GIO, pero evita relanzar una aplicación detectada abierta y devuelve un error explicativo. Otros errores de D-Bus no causan un relanzamiento automático. El método `FocusApp` estándar de GNOME selecciona una aplicación en el overview y está restringido; no equivale a activar su ventana.

En Ubuntu con GNOME 50, instalar y habilitar para el usuario actual:

```bash
make gnome
```

La primera instalación requiere cerrar sesión y volver a entrar para que GNOME descubra la extensión. No reiniciar ni reemplazar el compositor desde Pedro. El instalador respeta XDG_DATA_HOME y conserva las demás extensiones. Actualizaciones del JavaScript también pueden requerir una nueva sesión. La metadata declara la versión de GNOME verificada; versiones futuras requieren revisar compatibilidad.

Esta integración pertenece a la experiencia overlay GNOME. El pipeline actual de imagen con compositor propio tiene otra arquitectura y no se modifica ni se considera equivalente a esta sesión.

La barra de captura y la selección pertenecen a Qt/QML de Pedro. `Capture(iiii b b s) → (b s)` captura un área o inicia la grabación; devuelve el archivo real elegido por GNOME. `StopCapture() → b` finaliza la grabación iniciada por Pedro. La extensión utiliza `Shell.Screenshot` y `org.gnome.Shell.Screencast` sin abrir la barra de GNOME. Las imágenes se guardan como PNG y se copian al portapapeles; el servicio de grabación elige el formato compatible (MP4/WebM). PAPI prepara los directorios de imágenes/vídeos del usuario, retira la selección antes de capturar y comunica fallos a la barra. La grabación se detiene si desaparece el cliente Pedro o se desactiva la extensión.

El wallpaper de Pedro se registra en Mutter como `Meta.WindowType.DESKTOP`, en la capa de escritorio, en lugar de bajar una ventana normal después de cada cambio de foco. El shell cubre la pantalla sin solicitar fullscreen. Así, activar aplicaciones o pulsar menús y captura no eleva el wallpaper por encima de las ventanas. La regla solo identifica la ventana raíz «Pedro OS»; Files y otras ventanas conservan su tipo. Al deshabilitar la extensión se restauran los tipos originales.

Los visores internos usan `ActivateWindow(u pid, s title) → b`: GNOME busca una ventana del proceso Pedro con ese título, restaura la ventana y llama `Main.activateWindow()` con un timestamp actual. Si el nombre es ambiguo o falta la extensión, Qt conserva su solicitud nativa de activación. Una actualización de esta extensión requiere cerrar sesión y volver a entrar en GNOME para recargar el módulo; reiniciar solamente Pedro no recarga el servicio.

`PlaceWindow(u pid, s title, s shellTitle) → b` solicita al compositor GNOME la posición inicial de cada ventana recién abierta. La integración espera brevemente a que Mutter registre la superficie y distingue las carpetas con títulos iguales mediante sus secuencias estables. Calcula el desplazamiento con los rectángulos reales de carpetas y visores del mismo proceso, excluye la ventana del escritorio y respeta el área disponible del monitor. Qt mantiene reservas para las aperturas simultáneas; en Wayland las coordenadas Qt por sí solas no determinan la posición del compositor.

Los visores y carpetas nuevos reciben una identidad estable de Mutter mediante `PlaceWindowIdentity(u pid, s title, s shellTitle) → u`. Pedro serializa las solicitudes de colocación y guarda esa identidad en la ventana Qt. `ActivateWindowIdentity(u pid, u identity) → b` restaura y enfoca la ventana exacta aunque otras compartan su título; comprueba también el proceso propietario. Mientras una colocación está pendiente, el backend conserva la solicitud de foco. Los métodos anteriores se mantienen para sesiones con la extensión anterior. Cerrar y volver a abrir un visor genera una nueva identidad; un ID que ya no existe no activa otra ventana.
