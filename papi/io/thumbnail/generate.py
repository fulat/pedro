"""Use GNOME's registered thumbnailers and shared, validated thumbnail cache."""
import sys

import gi

gi.require_version("GnomeDesktop", "4.0")
from gi.repository import GnomeDesktop

uri, mime, modified = sys.argv[1:]
modified = int(modified)
factory = GnomeDesktop.DesktopThumbnailFactory.new(GnomeDesktop.DesktopThumbnailSize.LARGE)
try:
    cached = factory.lookup(uri, modified)
    if not cached and factory.can_thumbnail(uri, mime, modified):
        pixbuf = factory.generate_thumbnail(uri, mime, None)
        if pixbuf:
            factory.save_thumbnail(pixbuf, uri, modified, None)
            cached = factory.lookup(uri, modified)
        else:
            factory.create_failed_thumbnail(uri, modified, None)
    if cached:
        print(cached)
except Exception:
    # Unsupported/corrupt files keep the normal themed icon.
    sys.exit(1)
