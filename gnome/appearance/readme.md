# Apariencia de Pedro

Para instalar y activar los recursos de apariencia en la sesión GNOME del usuario actual:

```bash
python3 gnome/appearance/activate.py
```

El comando instala GTK e iconos bajo el directorio de datos XDG del usuario y selecciona `Pedro` para ambos temas. Utiliza el cursor `Yaru` de 24 px, según `gtk/Pedro/index.theme`. Requiere los recursos GTK de Yaru instalados en el sistema; reutiliza sus recursos para resolver los imports del CSS de Pedro.

Los enlaces de compatibilidad cuyo destino no existe se omiten durante la copia. Se puede volver a ejecutar el comando después de editar los recursos del proyecto. Las aplicaciones que mantengan en caché su apariencia pueden necesitar volver a abrirse.

El CSS controla widgets y decoraciones GTK. Qt Quick conserva sus componentes QML y utiliza la integración de plataforma y decoración de ventanas seleccionada por Qt; activar un tema GTK no convierte automáticamente los controles QML ni garantiza que una decoración Qt dibuje todos los detalles del CSS GTK.

## Ventanas Qt Quick de Pedro

`gui/qml/components/window/frame.qml` implementa el marco de las ventanas secundarias de Pedro en QML. Archivos utiliza este componente, con los controles rojo/amarillo/verde y el control azul de restauración del tema. Los iconos se empaquetan directamente desde `gnome/appearance/icons/Pedro` como recursos Qt y se renderizan con el proveedor SVG existente, también en production.

El componente recibe el título y una `contentSource` para reutilizarse con otras vistas. Conserva el material Liquid y obtiene su wallpaper de `Backend.wallpaper`. Qt solicita a Ubuntu mover, redimensionar, minimizar, maximizar y restaurar la ventana mediante sus APIs de ventana; el marco QML dibuja los controles. Las ventanas de aplicación son independientes del escritorio para permitir su minimización.

La activación se aplica al usuario actual. El empaquetado de estos recursos y sus valores predeterminados para nuevas sesiones de la ISO requiere integración en la instalación de Pedro.
