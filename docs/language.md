# Idiomas y configuración

Pedro usa los catálogos nativos de Qt: `gui/language/en.ts` y `es.ts`, compilados por `lrelease` a `.qm` dentro de `build/` y embebidos en el ejecutable. QML usa `qsTranslate("Pedro", "desktop.menu.folder")`; C++ usa `QCoreApplication::translate` con el mismo contexto y claves. Los JSON son únicamente metadatos de referencia para edición y futuras herramientas externas, no se leen en runtime. Al modificar traducciones, actualizar el catálogo `.ts` y la referencia JSON correspondiente. Los dos idiomas deben tener las mismas claves y placeholders.

Las preferencias globales se configuran juntas en `preferences.toml`. El idioma usa su propia sección:

```toml
[language]
current = "es" # o "en"
```

Los valores predeterminados viven en `gui/config/`, separados de las imágenes y catálogos. El mismo `preferences.toml` conserva los bloques existentes `[wallpaper.light]` y `[wallpaper.dark]`; se selecciona `wallpaper.light.current` o `wallpaper.dark.current` según `[appearance].mode`. El wallpaper seleccionado continúa llegando a QML exclusivamente mediante `Backend.wallpaper`.

PAPI (`Pedro::Papi::Config::Store`) resuelve cada TOML:

1. Archivo del usuario en `$XDG_CONFIG_HOME/pedro`, normalmente `~/.config/pedro`, si existe.
2. Valores predeterminados: `gui/config/` cuando `PEDRO_QML_DIR` apunta al source; `config/` junto al binario en desarrollo sin esa variable; `pedro/config/` en las ubicaciones XDG de datos en producción, instalado normalmente en `/usr/share/pedro/config`.

En desarrollo se pueden editar directamente `gui/config/preferences.toml`, salvo que exista un override del usuario. En producción, el primer arranque copia los defaults ausentes a la carpeta de configuración del usuario sin sobrescribir ajustes existentes. El usuario modifica esos archivos. Los assets siguen en las ubicaciones de datos, no en la configuración.

Qt observa archivos y directorios con `QFileSystemWatcher`, agrupa cambios durante 100 ms y vuelve a asociar archivos reemplazados mediante guardados atómicos. No hay polling. Cambiar el idioma instala su `QTranslator`, establece la locale de Qt y ejecuta `QQmlEngine::retranslate`; incluye el título de una ventana de Archivos ya abierta, menús, navegación y fecha. Un idioma inválido conserva la última selección válida; al iniciar, el fallback es español. Un wallpaper inválido conserva el anterior. No se renombran archivos del usuario al cambiar idioma. Nombres propios, nombres de aplicaciones externas y errores provenientes del sistema pueden seguir su propia locale.

`make setup` instala `qt6-l10n-tools`. Configurar/build no descarga herramientas; en un entorno sin instalación global puede indicarse `-DPEDRO_LRELEASE=/ruta/a/lrelease`. Todas las salidas generadas permanecen bajo `build/`. Los catálogos embebidos y defaults instalados se utilizan también en la ISO sin depender del source ni de Node.js.

## Apariencia light/dark

La sección `[appearance]` del mismo `preferences.toml` selecciona la apariencia sin reiniciar:

```toml
[appearance]
mode = "light" # o "dark"
```

El valor de `mode` selecciona `light` o `dark`; los defaults actuales están en el archivo fuente. PAPI observa este TOML con el mismo mecanismo y lo copia al perfil del usuario en producción cuando falta. Un modo inválido conserva el último modo válido. El liquid compartido reacciona a `Backend.appearanceMode`, con una tinta más luminosa en light y el material oscuro anterior en dark; conserva la muestra del wallpaper, el desenfoque y los textos blancos. El cambio de modo selecciona el wallpaper configurado para ese modo. Esto configura la apariencia de Pedro, no cambia el tema GTK de otras aplicaciones.

## Archivo global de preferencias

Idioma, apariencia y wallpaper comparten `gui/config/preferences.toml` y el override `$XDG_CONFIG_HOME/pedro/preferences.toml`. Se mantienen tablas TOML separadas dentro del mismo archivo. Otros dominios pueden tener sus propios TOML cuando su responsabilidad lo justifique; no crear un archivo por cada preferencia global.

Si falta el archivo unificado del usuario pero existen los anteriores `language.toml`, `appearance.toml` o `wallpaper.toml`, PAPI combina sus secciones con los defaults y guarda `preferences.toml` de forma atómica. Los originales se conservan como respaldo y dejan de leerse cuando existe el nuevo archivo. Un archivo unificado existente nunca se sobrescribe durante la migración. Se observa únicamente el nuevo archivo y sus directorios; todos los cambios de idioma, modo y wallpaper siguen siendo dinámicos.

## Zoom del dock

La sección `[dock]` de `preferences.toml` permite configurar `hoverScale = 1.20`. El valor es un factor: `1.20` amplía el icono un 20 %, y `1.0` desactiva el zoom. Se aceptan valores de 1.0 a 1.3 para evitar que los iconos se superpongan. El default es 1.20; valores inválidos conservan la última selección válida. PAPI lee el número TOML y la GUI lo expone mediante `Backend.dockHoverScale` y la propiedad `hoverScale` del dock, preparadas para la futura UI de preferencias. La transición de entrada/salida mantiene 180 ms y `InOutQuad`, sin fondo de hover.
