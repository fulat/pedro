#!/usr/bin/env python3
"""Install and activate Pedro's appearance for the current GNOME user."""

import os
from pathlib import Path
import shutil
import subprocess


def main():
    source = Path(__file__).resolve().parent
    data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    if not data.is_absolute():
        raise SystemExit("XDG_DATA_HOME must be an absolute path")

    # Pedro imports Yaru's registered GTK resources instead of duplicating its CSS.
    resources = {}
    roots = [data] + [Path(root) for root in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if root]
    for version in ("gtk-3.0", "gtk-4.0"):
        resource = next((root / "themes/Yaru" / version / "gtk.gresource"
                         for root in roots if (root / "themes/Yaru" / version / "gtk.gresource").is_file()), None)
        if resource is None:
            raise SystemExit(f"Missing Yaru resource for {version}; install yaru-theme-gtk first")
        resources[version] = resource

    theme = data / "themes/Pedro"
    shutil.copytree(source / "gtk/Pedro", theme, dirs_exist_ok=True, ignore_dangling_symlinks=True)
    shutil.copytree(source / "icons/Pedro", data / "icons/Pedro", dirs_exist_ok=True, ignore_dangling_symlinks=True)
    for version, resource in resources.items():
        shutil.copyfile(resource, theme / version / "gtk.gresource")

    settings = {"gtk-theme": "Pedro", "icon-theme": "Pedro", "cursor-theme": "Yaru", "cursor-size": "24"}
    for key in settings:
        writable = subprocess.check_output(["gsettings", "writable", "org.gnome.desktop.interface", key], text=True).strip()
        if writable != "true":
            raise SystemExit(f"GNOME setting is locked: {key}")
    for key, value in settings.items():
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], check=True)
    for key in settings:
        value = subprocess.check_output(["gsettings", "get", "org.gnome.desktop.interface", key], text=True).strip()
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
