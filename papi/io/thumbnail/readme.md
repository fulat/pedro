# Video thumbnails

`Pedro::Papi::Io::Thumbnail::image()` obtains a still image through GNOME's
DesktopThumbnailFactory using the registered GStreamer video thumbnailer. GNOME
owns URI/mtime validation, the shared thumbnail cache and failed-file records.
Pedro does not decode video frames or implement another thumbnail cache.

The function accepts local, readable video files and performs blocking work.
Consumers must call it on a worker thread. Pedro's Qt Quick image provider limits
concurrent requests to two and preserves themed icons until a thumbnail is ready.
The source revision invalidates Qt's image cache when a file changes.

Runtime requirements: system Python 3, python3-gi, gir1.2-gnomedesktop-4.0,
gst-video-thumbnailer and the corresponding GStreamer codecs. `setup.sh --preview`
and the Pedro staging pipeline include these dependencies. A missing decoder,
failed thumbnail, unreadable file or timeout keeps the normal icon.
