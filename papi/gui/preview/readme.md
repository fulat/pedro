# Internal file preview

`Pedro::Papi::Gui::Preview::Manager` is an independently consumable preview
session. It is a library API, not an application or a service. The shell opens
its existing Liquid Quick window on double-click or Space in Files/the desktop.
There is no Preview launcher in the dock or installed desktop entry.

The architecture follows [Sushi's MIME renderer selection](https://github.com/GNOME/sushi/blob/main/src/core/rendererSelector.js)
and [renderer lifecycle](https://github.com/GNOME/sushi/blob/main/src/core/renderer.js):
exact MIME matches, inherited types, family providers, then a fallback. Providers
have a common state and lifecycle. No Sushi UI or source code is incorporated.

Providers:

| Domain | Native backend | Initial capability |
| --- | --- | --- |
| Image | Glycin 2 | First image frame, orientation handled by Glycin; its default sandbox remains enabled |
| Document | Poppler GLib/Cairo | PDF pages, bounded raster size; encrypted files report the backend error |
| Media | GStreamer playbin/appsink | Video and audio, clocked playback, seeking, volume, mute, EOS/replay |
| Text | Qt Unicode decoder and Qt text layout | Read-only plain/source text, including literal HTML/XML, without executing or parsing markup |
| Unsupported | Built-in provider | A file-specific unavailable state |

The manager uses Qt's shared-mime-info-backed MIME database. File inspection,
image loading, document loading/rendering and text reads run outside the UI
thread. Request generations discard obsolete results. Closing clears the
session and stops/releases the media pipeline. An already-running immutable
image/PDF job can finish in the background, but cannot update a closed session.

`open(QUrl, QVariantList siblings)`, `close()`, `next()` and `previous()` control
a session. Document and playback controls use `setPage()`, `togglePlayback()`,
`seek()`, `volume` and `muted`. The public state supplies kind, name, MIME,
loading/error, text, page information, playback and frame revision. `frame()`
returns a thread-safe QImage surface. The GUI's thin QQuickImageProvider adapter
uploads these already-decoded pixels; QML imports no decoding libraries.
Other clients may create their own manager and consume the same API.

`registerProvider(mimeTypes, factory)` extends the registry. A later exact
registration overrides an earlier one. Providers live in semantic subdirectories
under this existing PAPI GUI domain and must not depend on `gui/`.

Space in the file window previews the selection; Space or Escape in the preview
window closes it. Left/Right move through the supplied file list. Page Up/Down
navigate PDF pages, K toggles playback, and Ctrl+0 fits the image/page. Image
zoom and rotation remain presentation state. Editable path/rename fields retain
normal Space input.

Current boundaries: local regular files only; office formats such as DOCX/ODT,
password entry, syntax highlighting and animated-image playback are not yet
implemented and do not trigger heavyweight conversion programs. Text is bounded
to 128 KiB, 2,000 lines and 4,096 characters per line, with a visible truncation
notice. Images over 40 million pixels report a size error. PDF rasters are capped
at 2,400 pixels per side. GStreamer codec support comes from installed plugins.

Build and runtime dependencies are declared in `papi/CMakeLists.txt`, `setup.sh`
and the staging pipeline. Normal development still uses `PEDRO_BUILD_IMAGE=OFF`.
The reusable API introduces no new top-level component and no systemd unit.

## Text editing

Text/source previews use Qt Quick TextArea in plain-text mode, including raw HTML and Markdown. Complete, writable previews are editable as soon as they open. Every text change is saved through the PAPI controller, without edit/save controls or file navigation arrows. Empty regular files open as text documents regardless of their extension; Qt content detection recognizes extensionless text. QSaveFile writes atomically without a direct-write fallback; the provider preserves the detected Unicode encoding, BOM and CRLF line endings. Saving rejects externally changed files, encoding failures, and contents above the 128 KiB preview limit. Truncated and read-only files stay read-only. If automatic saving fails, the UI retains the draft and blocks closing until saving succeeds or the user discards or cancels. PDF remains a Poppler page preview; DOCX/ODT editing requires a future document provider and is not implemented by treating binary office files as text.
