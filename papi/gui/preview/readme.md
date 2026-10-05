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


## File lifecycle

Each session owns `Papi::Io::File::Watch`, an independently reusable local-file watcher. GIO monitors the file and its ancestor locations; a retained file descriptor and bounded `/proc/self/fd` checks resolve Linux renames and moves of containing folders without searching the filesystem. The anchor is renewed after atomic replacement, including the editor's own QSaveFile writes. Notifications update `source`, `name` and the supplied playlist. `relocated` identifies a path change separately from opening a different file, so QML keeps window geometry, image zoom/rotation and any text draft. Loaded media streams and Poppler documents remain open, preserving position, pause/play, volume and page.

Consumers that perform file transfers can connect their transfer manager's `renamed` and `moved` signals to `Preview::Manager::relocate`. Pedro's Backend does this for every independent preview session. Successful GIO cut operations publish their actual destination, including completed children in a partially completed recursive move, so this path also handles copy/delete moves across filesystems. Reopening the new URL focuses the existing session through the existing Backend identity check.

`available` reports whether the current file exists. Clean text/image/PDF previews can reload on `fileChanged` through `reload()`; a text draft with a failed save is retained, including after deletion, and cannot be silently closed. Text saves refresh the location first and compare the bytes against the loaded snapshot at that location before writing. A relocation retries a pending save through the same conflict protection. External replacement of audio/video preserves the already-open stream rather than restarting playback.

External moves implemented as copy/delete with a new inode cannot be followed if GIO supplies no destination. The watcher reports the original file as unavailable, and the editor retains a failed-save draft rather than recreating the old path. This remaining integration case is recorded in `docs/TODO.md`. The session currently supports local regular files; it does not scan directories to guess a moved file's destination. GIO monitoring reference: [GFileMonitor flags](https://docs.gtk.org/gio/flags.FileMonitorFlags.html).
