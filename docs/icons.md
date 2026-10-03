# File icons

GIO remains the source of truth. Directory and desktop models request `standard::content-type` and expose:

- `contentType`: the unmodified GIO content type.
- `iconNames`: ordered names from `g_content_type_get_icon()` / `GThemedIcon`, followed by GIO's generic name and `text-x-generic`.
- `visualType`: `folder`, `image` for a local image thumbnail, or `themed`.

The shared helper is `Pedro::Papi::Io::Content::iconNames()` in `papi/io/content/icon.cpp`. The legacy `icon` field is retained for existing menus and stack presentation; it is no longer the file icon resolver. Directory `type` remains a human-readable description used by the list view.

Cards and tables both load `entry/item.qml`, which forwards the metadata to `desktop/Icon.qml`. The frontend contains no extension or MIME-specific mappings. Folder drawing and local image thumbnails remain unchanged.

The existing `Icons` image provider accepts `image://icons/theme/<percent-encoded JSON array of names>`. For each candidate in GIO order, when Pedro is active it checks Pedro's own MIME SVG and then `QIcon::fromTheme()`. Qt resolves the active theme's inheritance; Pedro declares `Inherits=Yaru,hicolor`. If no candidate can be rendered, the provider returns Pedro's `text-x-generic.svg`. Colors are preserved, and the requested physical size controls vector rendering.

`Icons::configureTheme()` registers the bundled icon-theme root without discarding Qt's standard search paths. Pedro is the default theme; `PEDRO_ICON_THEME` selects another theme. Own MIME SVG directories are read from `index.theme` with `Context=MimeTypes`. Rendering these SVGs uses the existing `QSvgRenderer`, avoiding dependency on an image-format plugin for Pedro assets. Inherited SVG-only themes need Qt's SVG icon plugin; `setup.sh` already includes `qt6-svg-plugins`. PNG icons from inherited themes also work without that plugin.

## Adding a Pedro MIME SVG

1. Obtain the icon name supplied by GIO for the content type, for example `application-pdf`.
2. Add `gnome/appearance/icons/Pedro/scalable/mimetypes/application-pdf.svg` using a scalable viewBox. No C++ or QML mapping is needed.
3. Run `make gui-build`. CMake discovers and bundles SVGs automatically, including the theme index. Normal installation also installs the theme under `usr/share/icons/Pedro`.
4. To make the same override available to GNOME applications on the development host, run the existing appearance activation script separately. Building Pedro does not change GNOME settings.

The existing `scalable/mimetypes` index section is sufficient for additional SVGs there. Additional directories must be declared in `Directories` with `Context=MimeTypes` and their standard size/type metadata.

## Verification

After configuring the development build, run `bash gui/tests/icons/mime.sh`. Fixtures and binaries live under `build/verification/mime/`. The checks exercise both real GIO models, PDF/ZIP/code names, Pedro SVG priority, Yaru/hicolor inheritance, unknown-type fallback, and the shared QML component for themed icons and image thumbnails. Existing desktop sorting and layout checks remain available under `gui/tests/desktop/`.
